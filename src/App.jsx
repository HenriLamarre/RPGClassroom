import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'
import { t } from './i18n'
import SetupWizard from './SetupWizard'
import SemesterHome from './SemesterHome'

// Students arrive from the class QR code with ?join=<code>; keep it through the email sign-in.
const joinCode = new URLSearchParams(location.search).get('join')
if (joinCode) localStorage.setItem('joinCode', joinCode)

export default function App() {
  const [chosenLang, setChosenLang] = useState(localStorage.getItem('lang'))
  const [session, setSession] = useState(null)
  const [email, setEmail] = useState('')
  const [message, setMessage] = useState('')
  const [memberships, setMemberships] = useState(null) // null = loading
  const [currentId, setCurrentId] = useState(null)
  const [creating, setCreating] = useState(false)

  const current = memberships?.find((m) => m.semester_id === currentId)
  // The student's own choice wins, then their saved setting, then the class language.
  const lang = chosenLang || current?.language || current?.semesters.language || 'fr'

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session))
    const { data } = supabase.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => data.subscription.unsubscribe()
  }, [])

  const loadMemberships = useCallback(async (selectId) => {
    const { data, error } = await supabase.from('members').select('semester_id, role, language, semesters(*)')
      .eq('user_id', session.user.id).order('joined_at', { ascending: false })
    if (error) return setMessage(t(lang, 'errorPrefix') + error.message)
    setMemberships(data)
    setCurrentId(selectId ?? data[0]?.semester_id ?? null)
  }, [session, lang])

  useEffect(() => {
    if (!session) return
    const code = localStorage.getItem('joinCode')
    if (!code) { loadMemberships(); return }
    supabase.rpc('join_semester', { code }).then(({ data, error }) => {
      localStorage.removeItem('joinCode')
      setMessage(error ? t(lang, 'errorPrefix') + error.message : t(lang, 'joined'))
      loadMemberships(data)
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps -- run once per sign-in
  }, [session])

  const toggleLang = () => {
    const next = lang === 'fr' ? 'en' : 'fr'
    localStorage.setItem('lang', next)
    setChosenLang(next)
  }

  const sendLink = async (e) => {
    e.preventDefault()
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: location.origin + location.pathname },
    })
    setMessage(error ? t(lang, 'errorPrefix') + error.message : t(lang, 'linkSent'))
  }

  let body
  if (!session) {
    body = (
      <form onSubmit={sendLink}>
        <h2>{t(lang, 'loginTitle')}</h2>
        <label>
          {t(lang, 'emailLabel')}
          <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <button type="submit">{t(lang, 'sendLink')}</button>
      </form>
    )
  } else if (creating) {
    body = (
      <SetupWizard
        lang={lang}
        onCancel={() => setCreating(false)}
        onCreated={(id) => { setCreating(false); loadMemberships(id) }}
      />
    )
  } else if (!memberships) {
    body = <p>{t(lang, 'loading')}</p>
  } else {
    body = (
      <>
        <nav className="row">
          {memberships.length > 1 && (
            <select value={currentId} onChange={(e) => setCurrentId(e.target.value)}>
              {memberships.map((m) => <option key={m.semester_id} value={m.semester_id}>{m.semesters.name}</option>)}
            </select>
          )}
          <button type="button" onClick={() => setCreating(true)}>{t(lang, 'createSemester')}</button>
        </nav>
        {current ? <SemesterHome lang={lang} semester={current.semesters} role={current.role} /> : <p>{t(lang, 'noClassYet')}</p>}
      </>
    )
  }

  return (
    <main lang={lang}>
      <header className="row">
        <h1>{t(lang, 'appName')}</h1>
        <button type="button" onClick={toggleLang}>{t(lang, 'language')}</button>
        {session && <button type="button" onClick={() => supabase.auth.signOut()}>{t(lang, 'signOut')}</button>}
      </header>
      {message && <p role="status">{message}</p>}
      {body}
    </main>
  )
}
