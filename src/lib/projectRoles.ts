export const PROJECT_ROLES = [
  'Product Manager',
  'Backend Developer',
  'Frontend Developer',
  'Mobile Developer',
  'AI Engineer',
  'DevOps Engineer',
  'Database Engineer',
  'UI/UX Designer',
  'QA Engineer',
  'Marketing',
  'Technical Writer',
  'Contributor',
  'Other',
] as const;

export type ProjectRole = (typeof PROJECT_ROLES)[number] | 'Founder';

export const getProjectRole = (role?: string | null): ProjectRole | string => role || 'Contributor';

export const getRoleEmoji = (role?: string | null) => ({
  Founder: '👑',
  'Product Manager': '📋',
  'Backend Developer': '⚙️',
  'Frontend Developer': '🌐',
  'Mobile Developer': '📱',
  'AI Engineer': '🤖',
  'DevOps Engineer': '☁️',
  'Database Engineer': '🗄️',
  'UI/UX Designer': '🎨',
  'QA Engineer': '🧪',
  Marketing: '📈',
  'Technical Writer': '📝',
  Contributor: '🤝',
  Other: '🎯',
}[getProjectRole(role)] || '🎯');
