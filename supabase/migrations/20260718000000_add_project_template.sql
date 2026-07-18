-- Existing rows stay usable while all newly-created projects have a template.
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS project_template text;

UPDATE public.projects
SET project_template = 'Other'
WHERE project_template IS NULL OR btrim(project_template) = '';

ALTER TABLE public.projects
  ALTER COLUMN project_template SET DEFAULT 'Other',
  ALTER COLUMN project_template SET NOT NULL;
