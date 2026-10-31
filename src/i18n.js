// All interface text, in French and English. Add a key to both languages.
const strings = {
  fr: {
    appName: 'RPG Classroom',
    loginTitle: 'Connexion',
    emailLabel: 'Ton courriel du cégep',
    sendLink: 'Recevoir un lien de connexion',
    linkSent: 'Lien envoyé! Vérifie ta boîte de courriel.',
    welcome: 'Bienvenue',
    joined: 'Tu as rejoint la classe.',
    signOut: 'Se déconnecter',
    language: 'English',
  },
  en: {
    appName: 'RPG Classroom',
    loginTitle: 'Sign in',
    emailLabel: 'Your college email',
    sendLink: 'Email me a sign-in link',
    linkSent: 'Link sent! Check your inbox.',
    welcome: 'Welcome',
    joined: 'You joined the class.',
    signOut: 'Sign out',
    language: 'Français',
  },
}

export const t = (lang, key) => strings[lang]?.[key] ?? strings.fr[key] ?? key
