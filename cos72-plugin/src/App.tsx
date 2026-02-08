import { passkeyClient } from '@better-auth/passkey/client'
import { createAuthClient } from 'better-auth/client'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import './App.css'

function App() {
  const [communityOrigin, setCommunityOrigin] = useState(() => {
    return localStorage.getItem('cos72.communityOrigin') ?? 'http://localhost:8787'
  })

  const authClient = useMemo(() => {
    return createAuthClient({
      baseURL: `${communityOrigin.replace(/\/$/, '')}/api/auth`,
      plugins: [passkeyClient()],
      fetchOptions: {
        onRequest(context) {
          const token = localStorage.getItem('cos72.authToken')
          if (token) {
            context.headers.set('authorization', `Bearer ${token}`)
          }
        },
        onSuccess(context) {
          const headerToken = context.response.headers.get('set-auth-token')
          if (headerToken) {
            localStorage.setItem('cos72.authToken', headerToken)
          }
        },
      },
    })
  }, [communityOrigin])

  const [authToken, setAuthToken] = useState(() => {
    return localStorage.getItem('cos72.authToken') ?? ''
  })

  const [sessionState, setSessionState] = useState<{
    isPending: boolean
    userEmail: string | null
    userName: string | null
    error: string | null
  }>({ isPending: true, userEmail: null, userName: null, error: null })

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [name, setName] = useState('')

  const [passkeyName, setPasskeyName] = useState('')

  const [bindItems, setBindItems] = useState<
    Array<{ id: string; kind: string; value: string; meta: string | null; createdAt: string }>
  >([])
  const [bindKind, setBindKind] = useState('')
  const [bindValue, setBindValue] = useState('')
  const [bindMeta, setBindMeta] = useState('')

  const [exportPayload, setExportPayload] = useState('')
  const [exportSignature, setExportSignature] = useState('')
  const [importPayload, setImportPayload] = useState('')
  const [importSignature, setImportSignature] = useState('')
  const [importResult, setImportResult] = useState<string | null>(null)

  const [busy, setBusy] = useState<string | null>(null)
  const [toast, setToast] = useState<string | null>(null)
  const toastTimeoutRef = useRef<number | null>(null)

  function showToast(message: string) {
    setToast(message)
    if (toastTimeoutRef.current) {
      window.clearTimeout(toastTimeoutRef.current)
    }
    toastTimeoutRef.current = window.setTimeout(() => {
      setToast(null)
      toastTimeoutRef.current = null
    }, 3500)
  }

  const refreshSession = useCallback(async () => {
    setSessionState((s) => ({ ...s, isPending: true, error: null }))
    try {
      const { data, error } = await authClient.getSession()
      if (error) {
        setSessionState({
          isPending: false,
          userEmail: null,
          userName: null,
          error: error.message || 'failed to get session',
        })
        return
      }
      setSessionState({
        isPending: false,
        userEmail: data?.user?.email ?? null,
        userName: data?.user?.name ?? null,
        error: null,
      })
    } catch (e) {
      setSessionState({
        isPending: false,
        userEmail: null,
        userName: null,
        error: e instanceof Error ? e.message : 'unknown error',
      })
    }
  }, [authClient])

  useEffect(() => {
    localStorage.setItem('cos72.communityOrigin', communityOrigin)
  }, [communityOrigin])

  useEffect(() => {
    refreshSession()
  }, [refreshSession])

  useEffect(() => {
    return () => {
      if (toastTimeoutRef.current) {
        window.clearTimeout(toastTimeoutRef.current)
      }
    }
  }, [])

  async function storeToken(token: string | null | undefined) {
    const t = token ?? ''
    setAuthToken(t)
    if (t) localStorage.setItem('cos72.authToken', t)
    else localStorage.removeItem('cos72.authToken')
  }

  async function signUpEmail() {
    setBusy('email')
    setImportResult(null)
    try {
      const { data, error } = await authClient.signUp.email({
        email: email.trim(),
        password,
        name: name.trim() || 'User',
      })
      if (error) {
        showToast(error.message || 'sign up failed')
        return
      }
      await storeToken(data.token)
      showToast('Signed up')
      await refreshSession()
    } finally {
      setBusy(null)
    }
  }

  async function signInEmail() {
    setBusy('email')
    setImportResult(null)
    try {
      const { data, error } = await authClient.signIn.email({
        email: email.trim(),
        password,
      })
      if (error) {
        showToast(error.message || 'sign in failed')
        return
      }
      await storeToken(data.token)
      showToast('Signed in')
      await refreshSession()
    } finally {
      setBusy(null)
    }
  }

  async function signInSocial(provider: 'google' | 'github') {
    setBusy(provider)
    setImportResult(null)
    try {
      const { data, error } = await authClient.signIn.social({
        provider,
        disableRedirect: true,
        callbackURL: window.location.href,
        newUserCallbackURL: window.location.href,
        errorCallbackURL: window.location.href,
      })
      if (error) {
        showToast(error.message || 'social sign in failed')
        return
      }
      if (data.redirect && data.url) {
        window.location.assign(data.url)
        return
      }
      await storeToken((data as { token?: string }).token ?? null)
      showToast('Signed in')
      await refreshSession()
    } finally {
      setBusy(null)
    }
  }

  async function signInPasskey() {
    setBusy('passkey-signin')
    setImportResult(null)
    try {
      const { error } = await authClient.signIn.passkey()
      if (error) {
        showToast(error.message || 'passkey sign in failed')
        return
      }
      const token = localStorage.getItem('cos72.authToken')
      setAuthToken(token ?? '')
      showToast('Signed in')
      await refreshSession()
    } finally {
      setBusy(null)
    }
  }

  async function registerPasskey() {
    setBusy('passkey-register')
    setImportResult(null)
    try {
      const { error } = await authClient.passkey.addPasskey({
        name: passkeyName.trim() || 'My passkey',
      })
      if (error) {
        showToast(error.message || 'add passkey failed')
        return
      }
      showToast('Passkey added')
    } finally {
      setBusy(null)
    }
  }

  async function signOut() {
    setBusy('signout')
    setImportResult(null)
    try {
      await authClient.signOut()
      await storeToken(null)
      showToast('Signed out')
      await refreshSession()
      setBindItems([])
      setExportPayload('')
      setExportSignature('')
      setImportPayload('')
      setImportSignature('')
    } finally {
      setBusy(null)
    }
  }

  async function communityApi(path: string, init?: RequestInit) {
    const url = `${communityOrigin.replace(/\/$/, '')}${path}`
    const headers = new Headers(init?.headers)
    const token = authToken || localStorage.getItem('cos72.authToken') || ''
    if (token) headers.set('authorization', `Bearer ${token}`)
    if (!headers.has('content-type') && init?.body) headers.set('content-type', 'application/json')
    const res = await fetch(url, { ...init, headers })
    const contentType = res.headers.get('content-type') ?? ''
    const data = contentType.includes('application/json') ? await res.json() : await res.text()
    return { ok: res.ok, status: res.status, data }
  }

  async function loadBindRelations() {
    setBusy('bind-load')
    setImportResult(null)
    try {
      const res = await communityApi('/api/bind-relations')
      if (!res.ok) {
        const message = typeof res.data?.error === 'string' ? res.data.error : 'failed'
        showToast(message)
        return
      }
      setBindItems(Array.isArray(res.data?.items) ? res.data.items : [])
    } finally {
      setBusy(null)
    }
  }

  async function addBindRelation() {
    setBusy('bind-add')
    setImportResult(null)
    try {
      const res = await communityApi('/api/bind-relations', {
        method: 'POST',
        body: JSON.stringify({
          kind: bindKind.trim(),
          value: bindValue.trim(),
          meta: bindMeta ? bindMeta : null,
        }),
      })
      if (!res.ok) {
        const message = typeof res.data?.error === 'string' ? res.data.error : 'failed'
        showToast(message)
        return
      }
      setBindKind('')
      setBindValue('')
      setBindMeta('')
      await loadBindRelations()
      showToast('Bind relation added')
    } finally {
      setBusy(null)
    }
  }

  async function deleteBindRelation(id: string) {
    setBusy(`bind-del:${id}`)
    setImportResult(null)
    try {
      const res = await communityApi(`/api/bind-relations/${encodeURIComponent(id)}`, { method: 'DELETE' })
      if (!res.ok) {
        const message = typeof res.data?.error === 'string' ? res.data.error : 'failed'
        showToast(message)
        return
      }
      await loadBindRelations()
      showToast('Deleted')
    } finally {
      setBusy(null)
    }
  }

  async function exportMigration() {
    setBusy('export')
    setImportResult(null)
    try {
      const res = await communityApi('/api/bind-relations/export')
      if (!res.ok) {
        const message = typeof res.data?.error === 'string' ? res.data.error : 'failed'
        showToast(message)
        return
      }
      setExportPayload(res.data.payload ?? '')
      setExportSignature(res.data.signature ?? '')
      showToast('Exported')
    } finally {
      setBusy(null)
    }
  }

  async function importMigration() {
    setBusy('import')
    setImportResult(null)
    try {
      let payload = importPayload.trim()
      let signature = importSignature.trim()

      if (!signature && payload.startsWith('{')) {
        const parsed = JSON.parse(payload) as { payload?: string; signature?: string }
        if (typeof parsed.payload === 'string') payload = parsed.payload
        if (typeof parsed.signature === 'string') signature = parsed.signature
      }

      const res = await communityApi('/api/bind-relations/import', {
        method: 'POST',
        body: JSON.stringify({ payload, signature }),
      })
      if (!res.ok) {
        const message = typeof res.data?.error === 'string' ? res.data.error : 'failed'
        setImportResult(message)
        showToast(message)
        return
      }
      const conflicts = Array.isArray(res.data?.conflicts) ? res.data.conflicts : []
      setImportResult(conflicts.length ? `conflicts: ${JSON.stringify(conflicts)}` : 'ok')
      await loadBindRelations()
      showToast('Imported')
    } catch (e) {
      const message = e instanceof Error ? e.message : 'unknown error'
      setImportResult(message)
      showToast(message)
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="page">
      <header className="header">
        <div className="brand">Cos72</div>
        <div className="headerRight">
          <div className="sessionLine">
            {sessionState.isPending ? (
              <span className="muted">Checking session…</span>
            ) : sessionState.userEmail ? (
              <span>
                {sessionState.userName ? `${sessionState.userName} · ` : ''}
                {sessionState.userEmail}
              </span>
            ) : (
              <span className="muted">Signed out</span>
            )}
          </div>
          <button className="btn" onClick={refreshSession} disabled={busy !== null}>
            Refresh
          </button>
          <button className="btn" onClick={signOut} disabled={busy !== null || !sessionState.userEmail}>
            Sign out
          </button>
        </div>
      </header>

      <section className="panel">
        <div className="panelTitle">Community server</div>
        <div className="row">
          <label className="label">Origin</label>
          <input
            className="input"
            value={communityOrigin}
            onChange={(e) => setCommunityOrigin(e.target.value)}
            placeholder="http://localhost:8787"
          />
        </div>
        <div className="row">
          <label className="label">Auth token</label>
          <input
            className="input"
            value={authToken}
            onChange={(e) => storeToken(e.target.value)}
            placeholder="(auto)"
          />
        </div>
        {sessionState.error ? <div className="errorBox">{sessionState.error}</div> : null}
      </section>

      <section className="panel">
        <div className="panelTitle">Login</div>
        <div className="grid2">
          <div className="stack">
            <div className="sectionTitle">Email</div>
            <div className="row">
              <label className="label">Name</label>
              <input className="input" value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="row">
              <label className="label">Email</label>
              <input className="input" value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
            <div className="row">
              <label className="label">Password</label>
              <input
                className="input"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            <div className="row actions">
              <button
                className="btn primary"
                onClick={signUpEmail}
                disabled={busy !== null || !email.trim() || !password || !name.trim()}
              >
                Sign up
              </button>
              <button className="btn primary" onClick={signInEmail} disabled={busy !== null || !email.trim() || !password}>
                Sign in
              </button>
            </div>
          </div>

          <div className="stack">
            <div className="sectionTitle">Passkey</div>
            <div className="row actions">
              <button className="btn primary" onClick={signInPasskey} disabled={busy !== null}>
                Sign in with passkey
              </button>
            </div>
            <div className="row">
              <label className="label">Passkey name</label>
              <input className="input" value={passkeyName} onChange={(e) => setPasskeyName(e.target.value)} />
            </div>
            <div className="row actions">
              <button
                className="btn"
                onClick={registerPasskey}
                disabled={busy !== null || !sessionState.userEmail || !passkeyName.trim()}
              >
                Add passkey (signed-in)
              </button>
            </div>

            <div className="sectionTitle">Social</div>
            <div className="row actions">
              <button className="btn" onClick={() => signInSocial('google')} disabled={busy !== null}>
                Continue with Google
              </button>
              <button className="btn" onClick={() => signInSocial('github')} disabled={busy !== null}>
                Continue with GitHub
              </button>
            </div>
          </div>
        </div>
      </section>

      <section className="panel">
        <div className="panelTitle">Bind relations</div>
        <div className="row actions">
          <button className="btn" onClick={loadBindRelations} disabled={busy !== null || !sessionState.userEmail}>
            Load
          </button>
          <button className="btn" onClick={exportMigration} disabled={busy !== null || !sessionState.userEmail}>
            Export
          </button>
        </div>

        <div className="grid2">
          <div className="stack">
            <div className="sectionTitle">Add</div>
            <div className="row">
              <label className="label">Kind</label>
              <input className="input" value={bindKind} onChange={(e) => setBindKind(e.target.value)} />
            </div>
            <div className="row">
              <label className="label">Value</label>
              <input className="input" value={bindValue} onChange={(e) => setBindValue(e.target.value)} />
            </div>
            <div className="row">
              <label className="label">Meta</label>
              <input className="input" value={bindMeta} onChange={(e) => setBindMeta(e.target.value)} />
            </div>
            <div className="row actions">
              <button
                className="btn primary"
                onClick={addBindRelation}
                disabled={busy !== null || !sessionState.userEmail || !bindKind.trim() || !bindValue.trim()}
              >
                Add relation
              </button>
            </div>
          </div>

          <div className="stack">
            <div className="sectionTitle">Export</div>
            <div className="row">
              <label className="label">Payload</label>
              <textarea className="textarea" value={exportPayload} readOnly />
            </div>
            <div className="row">
              <label className="label">Signature</label>
              <textarea className="textarea" value={exportSignature} readOnly />
            </div>
          </div>
        </div>

        <div className="grid2">
          <div className="stack">
            <div className="sectionTitle">Import</div>
            <div className="row">
              <label className="label">Payload</label>
              <textarea className="textarea" value={importPayload} onChange={(e) => setImportPayload(e.target.value)} />
            </div>
            <div className="row">
              <label className="label">Signature</label>
              <textarea
                className="textarea"
                value={importSignature}
                onChange={(e) => setImportSignature(e.target.value)}
              />
            </div>
            <div className="row actions">
              <button className="btn primary" onClick={importMigration} disabled={busy !== null || !sessionState.userEmail}>
                Import
              </button>
            </div>
            {importResult ? <div className="resultBox">{importResult}</div> : null}
          </div>

          <div className="stack">
            <div className="sectionTitle">Current</div>
            <div className="list">
              {bindItems.length ? (
                bindItems.map((it) => (
                  <div key={it.id} className="listItem">
                    <div className="listMain">
                      <div className="listTitle">
                        {it.kind}: {it.value}
                      </div>
                      {it.meta ? <div className="muted">{it.meta}</div> : null}
                    </div>
                    <button className="btn danger" onClick={() => deleteBindRelation(it.id)} disabled={busy !== null}>
                      Delete
                    </button>
                  </div>
                ))
              ) : (
                <div className="muted">No bind relations loaded</div>
              )}
            </div>
          </div>
        </div>
      </section>

      {toast ? <div className="toast">{toast}</div> : null}
    </div>
  )
}

export default App
