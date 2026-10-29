import { en } from './en';
import { zh } from './zh';
import type { Locale, Translations } from './types';

export type { Locale, Translations } from './types';

const dictionaries: Record<Locale, Translations> = { zh, en };

export function getTranslations(locale: Locale = 'zh'): Translations {
  return dictionaries[locale] ?? zh;
}

export function getAlternateLocale(locale: Locale): Locale {
  return locale === 'zh' ? 'en' : 'zh';
}

export function getLocalePath(locale: Locale): string {
  return locale === 'en' ? '/en/' : '/';
}
