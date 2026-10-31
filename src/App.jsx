import { useEffect, useState } from 'react'
import { supabase } from './supabase'
import { t } from './i18n'

// Students arrive from the class QR code with ?join=<code>; keep it through the email sign-in.
const joinCode = new URLSearchParams(location.search).get('join')
if (joinCode) localStorage.setItem('joinCode', joinCode)

export default function App() {
  const [lang, setLang] = useState(localStorage.getItem('lang') || 'fr')
  const [session, setSession] = useState(null)
  const [email, setEmail] = useState('')
  const [message, setMessage] = useState('')

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session))
    const { data } = supabase.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => data.subscription.unsubscribe()
  }, [])

  useEffect(() => {
    const code = localStorage.getItem('joinCode')
    if (!session || !code) return
    supabase.rpc('join_semester', { code }).then(({ error }) => {
      localStorage.removeItem('joinCode')
      setMessage(error ? error.message : t(lang, 'joined'))
    })
  }, [session, lang])

  const toggleLang = () => {
    const next = lang === 'fr' ? 'en' : 'fr'
    localStorage.setItem('lang', next)
    setLang(next)
  }

  const sendLink = async (e) => {
    e.preventDefault()
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: location.origin + location.pathname },
    })
    setMessage(error ? error.message : t(lang, 'linkSent'))
  }

  return (
    <main lang={lang}>
      <header>
        <h1>{t(lang, 'appName')}</h1>
        <button type="button" onClick={toggleLang}>{t(lang, 'language')}</button>
      </header>

      {session ? (
        <section>
          <p>{t(lang, 'welcome')}, {session.user.email}</p>
          <button type="button" onClick={() => supabase.auth.signOut()}>{t(lang, 'signOut')}</button>
        </section>
      ) : (
        <form onSubmit={sendLink}>
          <h2>{t(lang, 'loginTitle')}</h2>
          <label>
            {t(lang, 'emailLabel')}
            <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
          </label>
          <button type="submit">{t(lang, 'sendLink')}</button>
        </form>
      )}

      {message && <p role="status">{message}</p>}
    </main>
  )
}
