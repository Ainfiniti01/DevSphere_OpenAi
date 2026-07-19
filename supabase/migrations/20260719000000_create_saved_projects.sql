CREATE TABLE IF NOT EXISTS public.saved_projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT saved_projects_user_project_key UNIQUE (user_id, project_id)
);

ALTER TABLE public.saved_projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own saved projects"
ON public.saved_projects FOR SELECT TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can save projects for themselves"
ON public.saved_projects FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove their own saved projects"
ON public.saved_projects FOR DELETE TO authenticated
USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS saved_projects_user_created_at_idx
ON public.saved_projects (user_id, created_at DESC);
