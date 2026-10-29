export type Locale = 'zh' | 'en';

export type DemoStep = {
  num: string;
  title: string;
  desc: string;
  icon: string;
};

export type FeatureItem = {
  title?: string;
  description: string;
  decor: string;
  visual: 'tabs' | 'spark' | 'drag' | 'sliders' | 'window' | 'theme';
  accent: string;
};

export type HideMode = {
  name: string;
  description: string;
  tag: string;
  decor: string;
};

export type InstallStep = {
  title: string;
  detail: string;
};

export type UsageStep = {
  text: string;
};

export type NavItem = {
  href: string;
  label: string;
};

export type Translations = {
  locale: Locale;
  langLabel: string;
  meta: {
    title: string;
    description: string;
    themeColor: string;
  };
  header: {
    nav: NavItem[];
    download: string;
    githubAria: string;
  };
  hero: {
    badge: string;
    titlePrefix: string;
    titleHighlight: string;
    description: string;
    download: string;
    demo: string;
    source: string;
  };
  demo: {
    titlePrefix: string;
    titleHighlight: string;
    lead: string;
    steps: DemoStep[];
    tagline: string;
    stepsAria: string;
  };
  showcase: {
    pillPrimary: string;
    pillGhost: string;
    titleLine1: string;
    titleLine2: string;
    leadPrefix: string;
    leadEmphasis: string;
    leadSuffix: string;
    features: FeatureItem[];
    modesTitle: string;
    modesLead: string;
    modes: HideMode[];
    permission: string;
    downloadTag: string;
    downloadTitle: string;
    downloadLead: string;
    downloadDmg: string;
    downloadZip: string;
    allReleases: string;
    downloadReq: string;
    installSteps: InstallStep[];
    gettingStartedTag: string;
    gettingStartedTitle: string;
    usageSteps: UsageStep[];
    buildFromSource: string;
    buildBadge: string;
    ctaLabel: string;
    ctaTitlePrefix: string;
    ctaTitleHighlight: string;
    ctaLead: string;
    ctaDownload: string;
    ctaGithub: string;
  };
  footer: {
    developer: string;
    gettingStarted: string;
  };
  author: {
    label: string;
    aria: string;
  };
  pronunciation: {
    aria: string;
  };
  theme: {
    light: string;
    dark: string;
    toggle: string;
  };
  localeToggle: {
    label: string;
    switchTo: string;
  };
};
