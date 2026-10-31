import { useState } from 'react'
import { supabase } from './supabase'
import { t } from './i18n'
import { parseRoster } from './roster'

const STEPS = ['stepBasics', 'stepCurrency', 'stepLeaderboard', 'stepJoin']

// Prompts the teacher through a new semester's settings, then creates it.
export default function SetupWizard({ lang, onCreated, onCancel }) {
  const [step, setStep] = useState(0)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [rosterText, setRosterText] = useState('')
  const [s, setS] = useState({
    name: '',
    language: lang,
    currency_name: 'Écus',
    currency_icon: '🪙',
    poll_base_amount: 10,
    poll_max_bet: 50,
    leaderboard_enabled: true,
    leaderboard_size: 10,
    join_mode: 'roster',
    allowed_email_domain: '',
  })
  const set = (key) => (e) => {
    const { type, value, checked } = e.target
    setS({ ...s, [key]: type === 'checkbox' ? checked : type === 'number' ? Number(value) : value })
  }
  const roster = parseRoster(rosterText)
  const L = (key) => t(lang, key)

  const create = async () => {
    setBusy(true)
    setError('')
    // Client-made id: the new row is only readable after the trigger adds us as teacher.
    const id = crypto.randomUUID()
    const semester = { ...s, id, allowed_email_domain: s.join_mode === 'open' && s.allowed_email_domain.trim() || null }
    let { error } = await supabase.from('semesters').insert(semester)
    if (!error && s.join_mode === 'roster' && roster.length) {
      ;({ error } = await supabase.from('roster').insert(roster.map((r) => ({ ...r, semester_id: id }))))
    }
    setBusy(false)
    if (error) setError(L('errorPrefix') + error.message)
    else onCreated(id)
  }

  const last = step === STEPS.length - 1
  const canGoOn = step === 0 ? s.name.trim() : step === 3 && s.join_mode === 'roster' ? roster.length > 0 : true

  return (
    <form onSubmit={(e) => { e.preventDefault(); if (last) create(); else setStep(step + 1) }}>
      <h2>{L('createSemester')} · {step + 1}/{STEPS.length} · {L(STEPS[step])}</h2>

      {step === 0 && (
        <>
          <label>{L('semesterName')}
            <input required value={s.name} onChange={set('name')} placeholder={L('semesterNamePlaceholder')} />
          </label>
          <label>{L('classLanguage')}
            <select value={s.language} onChange={set('language')}>
              <option value="fr">Français</option>
              <option value="en">English</option>
            </select>
          </label>
        </>
      )}

      {step === 1 && (
        <>
          <p>{L('currencyHelp')}</p>
          <label>{L('currencyName')}<input required value={s.currency_name} onChange={set('currency_name')} /></label>
          <label>{L('currencyIcon')}<input required maxLength={4} value={s.currency_icon} onChange={set('currency_icon')} /></label>
          <label>{L('pollBase')}<input type="number" min={0} required value={s.poll_base_amount} onChange={set('poll_base_amount')} /></label>
          <label>{L('pollMaxBet')}<input type="number" min={0} required value={s.poll_max_bet} onChange={set('poll_max_bet')} /></label>
        </>
      )}

      {step === 2 && (
        <>
          <p>{L('leaderboardHelp')}</p>
          <label className="row"><input type="checkbox" checked={s.leaderboard_enabled} onChange={set('leaderboard_enabled')} />{L('leaderboardEnabled')}</label>
          {s.leaderboard_enabled && (
            <label>{L('leaderboardSize')}<input type="number" min={1} max={100} required value={s.leaderboard_size} onChange={set('leaderboard_size')} /></label>
          )}
        </>
      )}

      {step === 3 && (
        <>
          <label className="row"><input type="radio" name="join" checked={s.join_mode === 'roster'} onChange={() => setS({ ...s, join_mode: 'roster' })} />{L('joinRoster')}</label>
          <label className="row"><input type="radio" name="join" checked={s.join_mode === 'open'} onChange={() => setS({ ...s, join_mode: 'open' })} />{L('joinOpen')}</label>
          {s.join_mode === 'roster' ? (
            <label>{L('rosterLabel')}
              <textarea rows={8} value={rosterText} onChange={(e) => setRosterText(e.target.value)} />
              <small>{roster.length} {L('rosterCount')}</small>
            </label>
          ) : (
            <label>{L('domainLabel')}
              <input value={s.allowed_email_domain} onChange={set('allowed_email_domain')} placeholder={L('domainPlaceholder')} />
            </label>
          )}
        </>
      )}

      <div className="row">
        <button type="button" onClick={() => (step ? setStep(step - 1) : onCancel())}>{L('back')}</button>
        <button type="submit" disabled={!canGoOn || busy}>{last ? L('create') : L('next')}</button>
      </div>
      {error && <p role="alert">{error}</p>}
    </form>
  )
}
