-- Make roles explicit without breaking existing memberships.
ALTER TABLE public.project_members
  ADD COLUMN IF NOT EXISTS role text;

UPDATE public.project_members
SET role = 'Contributor'
WHERE role IS NULL OR btrim(role) = '';

-- Ensure every existing owner is represented as the one Founder for their project.
INSERT INTO public.project_members (project_id, user_id, status, role)
SELECT p.id, p.creator_id, 'active', 'Founder'
FROM public.projects p
WHERE NOT EXISTS (
  SELECT 1 FROM public.project_members pm
  WHERE pm.project_id = p.id AND pm.user_id = p.creator_id
);

UPDATE public.project_members pm
SET role = CASE WHEN pm.user_id = p.creator_id THEN 'Founder' ELSE 'Contributor' END,
    status = CASE WHEN pm.user_id = p.creator_id THEN 'active' ELSE pm.status END
FROM public.projects p
WHERE p.id = pm.project_id;

ALTER TABLE public.project_members
  ALTER COLUMN role SET DEFAULT 'Contributor',
  ALTER COLUMN role SET NOT NULL;

-- New projects always get an active Founder membership.
CREATE OR REPLACE FUNCTION public.add_project_founder_membership()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.project_members (project_id, user_id, status, role)
  SELECT NEW.id, NEW.creator_id, 'active', 'Founder'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.project_members
    WHERE project_id = NEW.id AND user_id = NEW.creator_id
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS projects_add_founder_membership ON public.projects;
CREATE TRIGGER projects_add_founder_membership
AFTER INSERT ON public.projects
FOR EACH ROW EXECUTE FUNCTION public.add_project_founder_membership();

-- Prevent duplicate Founders or removing the sole Founder through membership edits.
CREATE OR REPLACE FUNCTION public.protect_project_founder_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' AND OLD.role = 'Founder' THEN
    RAISE EXCEPTION 'Transfer project ownership before removing the Founder';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.role = 'Founder' AND
     (NEW.role IS DISTINCT FROM 'Founder' OR NEW.status IS DISTINCT FROM 'active') THEN
    RAISE EXCEPTION 'Transfer project ownership before changing or removing the Founder role';
  END IF;

  IF NEW.role = 'Founder' AND EXISTS (
    SELECT 1 FROM public.project_members pm
    WHERE pm.project_id = NEW.project_id
      AND pm.role = 'Founder'
      AND (TG_OP = 'INSERT' OR pm.user_id <> OLD.user_id)
  ) THEN
    RAISE EXCEPTION 'A project can only have one Founder';
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.role IS DISTINCT FROM OLD.role AND NOT EXISTS (
    SELECT 1 FROM public.project_members
    WHERE project_id = NEW.project_id AND user_id = auth.uid()
      AND status = 'active' AND role = 'Founder'
  ) THEN
    RAISE EXCEPTION 'Only the Founder can change project roles';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS project_members_protect_founder_role ON public.project_members;
CREATE TRIGGER project_members_protect_founder_role
BEFORE INSERT OR UPDATE OR DELETE ON public.project_members
FOR EACH ROW EXECUTE FUNCTION public.protect_project_founder_role();

-- Role changes use the existing project_members subscriptions.
DO $$
DECLARE
  realtime_covers_all_tables boolean;
BEGIN
  SELECT puballtables
  INTO realtime_covers_all_tables
  FROM pg_publication
  WHERE pubname = 'supabase_realtime';

  -- A FOR ALL TABLES publication already includes project_members.
  IF realtime_covers_all_tables IS DISTINCT FROM false THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_rel pr
    JOIN pg_class c ON c.oid = pr.prrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE pr.prpubid = (SELECT oid FROM pg_publication WHERE pubname = 'supabase_realtime')
      AND n.nspname = 'public' AND c.relname = 'project_members'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.project_members;
  END IF;
END;
$$;
