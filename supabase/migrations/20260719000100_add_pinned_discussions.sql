ALTER TABLE public.comments
  ADD COLUMN IF NOT EXISTS is_pinned boolean NOT NULL DEFAULT false;

-- Guarantees one pinned discussion per project without limiting normal discussions.
CREATE UNIQUE INDEX IF NOT EXISTS comments_one_pinned_per_project_idx
ON public.comments (project_id)
WHERE is_pinned;

CREATE OR REPLACE FUNCTION public.pin_project_discussion(p_comment_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_project_id uuid;
BEGIN
  SELECT project_id INTO target_project_id
  FROM public.comments WHERE id = p_comment_id;

  IF target_project_id IS NULL THEN
    RAISE EXCEPTION 'Discussion not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.project_members
    WHERE project_id = target_project_id
      AND user_id = auth.uid()
      AND status = 'active'
      AND role = 'Founder'
  ) THEN
    RAISE EXCEPTION 'Only the Project Founder can pin discussions';
  END IF;

  UPDATE public.comments
  SET is_pinned = false
  WHERE project_id = target_project_id AND is_pinned;

  UPDATE public.comments
  SET is_pinned = true
  WHERE id = p_comment_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.unpin_project_discussion(p_comment_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_project_id uuid;
BEGIN
  SELECT project_id INTO target_project_id
  FROM public.comments WHERE id = p_comment_id;

  IF target_project_id IS NULL THEN
    RAISE EXCEPTION 'Discussion not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.project_members
    WHERE project_id = target_project_id
      AND user_id = auth.uid()
      AND status = 'active'
      AND role = 'Founder'
  ) THEN
    RAISE EXCEPTION 'Only the Project Founder can unpin discussions';
  END IF;

  UPDATE public.comments SET is_pinned = false WHERE id = p_comment_id;
END;
$$;
