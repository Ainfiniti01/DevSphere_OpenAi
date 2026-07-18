export const PROJECT_TEMPLATES = [
  'Web Application', 'Mobile Application', 'Desktop Application', 'AI Agent',
  'SaaS', 'Open Source', 'API / Backend', 'Game', 'IoT / Robotics',
  'Developer Tool', 'Browser Extension', 'CLI Tool', 'Hackathon Project',
  'Startup', 'Research Project', 'Other',
] as const;

export type ProjectTemplate = (typeof PROJECT_TEMPLATES)[number];

/** Keeps projects created before templates were introduced discoverable. */
export const getProjectTemplate = (template?: string | null): ProjectTemplate | string => template || 'Other';
