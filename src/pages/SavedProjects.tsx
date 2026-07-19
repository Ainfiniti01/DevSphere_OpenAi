"use client";

import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bookmark, Loader2, User } from 'lucide-react';
import AppLayout from '@/components/layout/AppLayout';
import EmptyState from '@/components/EmptyState';
import SkillBadge from '@/components/SkillBadge';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { useApp } from '@/context/AppContext';
import { supabase } from '@/lib/supabase';
import { getProjectTemplate } from '@/lib/projectTemplates';

const SavedProjects = () => {
  const navigate = useNavigate();
  const { currentUser, savedProjects } = useApp();
  const [items, setItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadSavedProjects = async () => {
      if (!supabase || !currentUser?.id) return;
      setLoading(true);
      try {
        const { data, error } = await supabase
          .from('saved_projects')
          .select(`
            project_id, created_at,
            project:projects(
              id, title, stage, project_template, skills_required, thumbnail_url, status,
              creator:profiles!projects_creator_id_fkey(id, name, avatar_url, display_name, title)
            )
          `)
          .eq('user_id', currentUser.id)
          .order('created_at', { ascending: false });

        if (error) throw error;
        // A cascade removes deleted projects. The filter is an extra guard for legacy data.
        setItems((data || []).filter((item: any) => item.project));
      } catch (error: any) {
        console.error('Failed to load saved projects:', error.message);
      } finally {
        setLoading(false);
      }
    };

    loadSavedProjects();
  }, [currentUser?.id]);

  const visibleItems = items.filter(item => savedProjects[item.project_id]);

  return (
    <AppLayout title="Saved Projects" showBack>
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {loading ? (
          <div className="flex justify-center py-32"><Loader2 className="animate-spin text-primary" size={32} /></div>
        ) : visibleItems.length === 0 ? (
          <EmptyState
            icon={Bookmark}
            title="No saved projects yet."
            description="Save projects you want to revisit, collaborate on, or follow later."
            actionLabel="Explore Projects"
            actionPath="/explore"
          />
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
            {visibleItems.map((item: any) => {
              const project = item.project;
              const isPaused = project.status === 'PAUSED';
              const isArchived = project.status === 'ARCHIVED';
              return (
                <button
                  key={item.project_id}
                  onClick={() => navigate(`/project/${project.id}`)}
                  className="text-left overflow-hidden rounded-3xl border border-border bg-card shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all"
                >
                  <div className="relative aspect-video bg-accent/30">
                    {project.thumbnail_url ? (
                      <img src={project.thumbnail_url} alt={project.title} className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full bg-gradient-to-br from-primary/15 via-violet-500/10 to-background flex items-center justify-center">
                        <Bookmark className="text-primary/40" size={40} fill="currentColor" />
                      </div>
                    )}
                    <div className="absolute top-3 left-3 flex flex-wrap gap-2">
                      <span className="px-2.5 py-1 bg-primary/90 text-white text-[10px] font-black rounded-full uppercase tracking-wider">{project.stage}</span>
                      <span className="px-2.5 py-1 bg-primary/90 text-white text-[10px] font-black rounded-full uppercase tracking-wider">{getProjectTemplate(project.project_template)}</span>
                      {isPaused && <span className="px-2.5 py-1 bg-amber-500 text-white text-[10px] font-black rounded-full uppercase tracking-wider">Paused</span>}
                      {isArchived && <span className="px-2.5 py-1 bg-muted-foreground text-white text-[10px] font-black rounded-full uppercase tracking-wider">Archived</span>}
                    </div>
                  </div>
                  <div className="p-5 space-y-4">
                    <div>
                      <h2 className="text-lg font-black line-clamp-1">{project.title}</h2>
                      <div className="flex items-center gap-2 mt-2 text-sm text-muted-foreground">
                        <Avatar className="h-6 w-6"><AvatarImage src={project.creator?.avatar_url} /><AvatarFallback><User size={12} /></AvatarFallback></Avatar>
                        <span className="truncate">{project.creator?.display_name || project.creator?.name || 'Unknown creator'}</span>
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-1.5">
                      {(project.skills_required || []).slice(0, 3).map((skill: string) => <SkillBadge key={skill} skill={skill} />)}
                    </div>
                    <p className="text-[11px] font-bold text-muted-foreground">Saved {new Date(item.created_at).toLocaleDateString()}</p>
                  </div>
                </button>
              );
            })}
          </div>
        )}
      </div>
    </AppLayout>
  );
};

export default SavedProjects;
