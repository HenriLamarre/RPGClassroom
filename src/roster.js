// Turns a pasted list or CSV (one student per line, any separator) into roster rows.
// The email is found anywhere on the line; the other fields become the name.
const EMAIL = /[^\s,;<>"]+@[^\s,;<>"]+\.[^\s,;<>"]+/

export function parseRoster(text) {
  const rows = new Map()
  for (const line of text.split(/\r?\n/)) {
    const match = line.match(EMAIL)
    if (!match) continue // header or blank line
    const email = match[0].toLowerCase()
    const name = line.replace(match[0], '').split(/[,;\t]/).map((s) => s.trim().replace(/^"|"$/g, '')).filter(Boolean).join(' ')
    if (!rows.has(email) || name) rows.set(email, { email, real_name: name || null })
  }
  return [...rows.values()]
}
