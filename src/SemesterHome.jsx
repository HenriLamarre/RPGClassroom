import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { t } from './i18n'

// Landing page for one semester. Teachers get the join QR code.
export default function SemesterHome({ lang, semester, role }) {
  const [qr, setQr] = useState('')
  const joinUrl = `${location.origin}${location.pathname}?join=${semester.join_code}`

  useEffect(() => {
    if (role === 'teacher') QRCode.toDataURL(joinUrl, { width: 320, margin: 1 }).then(setQr)
  }, [role, joinUrl])

  return (
    <section>
      <h2>{semester.currency_icon} {semester.name}</h2>
      <p>{t(lang, role)}</p>
      {role === 'teacher' && (
        <>
          <h3>{t(lang, 'joinQrTitle')}</h3>
          <p>{t(lang, 'joinQrHelp')}</p>
          {qr && <img src={qr} width={320} height={320} alt={joinUrl} />}
          <p><a href={joinUrl}>{joinUrl}</a></p>
        </>
      )}
    </section>
  )
}
