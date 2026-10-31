import assert from 'node:assert/strict'
import { test } from 'node:test'
import { parseRoster } from './roster.js'

test('parses emails with names in any column, skips headers, dedupes', () => {
  const rows = parseRoster(`Nom,Prénom,Courriel
Roy,Ana,Ana.Roy@cegep.qc.ca
"Tremblay";"Ben";ben@cegep.qc.ca
eve@cegep.qc.ca

ana.roy@cegep.qc.ca`)
  assert.deepEqual(rows, [
    { email: 'ana.roy@cegep.qc.ca', real_name: 'Roy Ana' },
    { email: 'ben@cegep.qc.ca', real_name: 'Tremblay Ben' },
    { email: 'eve@cegep.qc.ca', real_name: null },
  ])
})
