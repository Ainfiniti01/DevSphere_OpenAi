-- Store only the pinned message reference; message content remains in messages.
ALTER TABLE public.projects
  ADD COLUMN IF NOT EXISTS pinned_chat_message_id uuid
  REFERENCES public.messages(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.can_manage_project_pins(p_project_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.project_members
    WHERE project_id = p_project_id AND user_id = auth.uid()
      AND status = 'active' AND role = 'Founder'
  ) OR COALESCE((SELECT is_admin FROM public.profiles WHERE id = auth.uid()), false);
$$;

-- Extend public-discussion pinning to platform admins as well as active Founders.
CREATE OR REPLACE FUNCTION public.pin_project_discussion(p_comment_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE target_project_id uuid;
BEGIN
  SELECT project_id INTO target_project_id FROM public.comments WHERE id = p_comment_id;
  IF target_project_id IS NULL THEN RAISE EXCEPTION 'Discussion not found'; END IF;
  IF NOT public.can_manage_project_pins(target_project_id) THEN
    RAISE EXCEPTION 'Only a Project Founder or admin can pin discussions';
  END IF;
  UPDATE public.comments SET is_pinned = false WHERE project_id = target_project_id AND is_pinned;
  UPDATE public.comments SET is_pinned = true WHERE id = p_comment_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.unpin_project_discussion(p_comment_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE target_project_id uuid;
BEGIN
  SELECT project_id INTO target_project_id FROM public.comments WHERE id = p_comment_id;
  IF target_project_id IS NULL THEN RAISE EXCEPTION 'Discussion not found'; END IF;
  IF NOT public.can_manage_project_pins(target_project_id) THEN
    RAISE EXCEPTION 'Only a Project Founder or admin can unpin discussions';
  END IF;
  UPDATE public.comments SET is_pinned = false WHERE id = p_comment_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.pin_project_chat_message(p_message_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE target_project_id uuid;
BEGIN
  SELECT project_id INTO target_project_id FROM public.messages WHERE id = p_message_id;
  IF target_project_id IS NULL THEN RAISE EXCEPTION 'Project chat message not found'; END IF;
  IF NOT public.can_manage_project_pins(target_project_id) THEN
    RAISE EXCEPTION 'Only a Project Founder or admin can pin messages';
  END IF;
  UPDATE public.projects SET pinned_chat_message_id = p_message_id WHERE id = target_project_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.unpin_project_chat_message(p_project_id uuid, p_message_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.can_manage_project_pins(p_project_id) THEN
    RAISE EXCEPTION 'Only a Project Founder or admin can unpin messages';
  END IF;
  UPDATE public.projects SET pinned_chat_message_id = NULL
  WHERE id = p_project_id AND pinned_chat_message_id = p_message_id;
END;
$$;
