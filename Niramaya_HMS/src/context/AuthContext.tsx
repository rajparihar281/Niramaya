import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import { getLocalUsers } from '@/lib/mockData';
import { supabase } from '@/lib/supabaseClient';
import { useWindowStore } from '@/stores/windowStore';
import type { Profile, UserRole } from '@/types';

// ─── Types ───────────────────────────────────────────────────────
interface AppUser {
  id: string;
  email: string;
}

interface AuthContextValue {
  user: AppUser | null;
  profile: Profile | null;
  loading: boolean;
  // email + password are primary; role is optional display hint, NOT used for auth decisions
  login: (email: string, password: string) => Promise<{ error: string | null }>;
  signup: () => Promise<{ error: string | null }>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

// ─── Session Persistence ─────────────────────────────────────────
const SESSION_KEY = 'niramaya_hms_session';

interface StoredSession {
  auth_id: string;
  user_id?: string;
  role?: string;
  email?: string;
  full_name?: string;
}

function getStoredSession(): StoredSession | null {
  try {
    const val = sessionStorage.getItem(SESSION_KEY);
    return val ? JSON.parse(val) : null;
  } catch {
    return null;
  }
}

function writeSession(payload: StoredSession) {
  // Use sessionStorage (tab-scoped) so sessions don't bleed across browser restarts.
  // localStorage is still cleared on logout for any legacy keys.
  sessionStorage.setItem(SESSION_KEY, JSON.stringify(payload));
}

function clearSession() {
  sessionStorage.removeItem(SESSION_KEY);
  // Also wipe any legacy localStorage keys from previous builds
  localStorage.removeItem('niramaya_hms_session');
  localStorage.removeItem('niramaya_local_session');
}

// ─── Provider ────────────────────────────────────────────────────
export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AppUser | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  // Restore session on cold load
  useEffect(() => {
    const session = getStoredSession();
    if (session) {
      setUser({ id: session.auth_id, email: session.email || session.auth_id });
      setProfile({
        id: session.user_id || session.auth_id,
        email: session.email || '',
        full_name: session.full_name || session.email || 'System User',
        role: (session.role?.toLowerCase() as UserRole) || 'doctor',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });
    }
    setLoading(false);
  }, []);

  // ── Login — email + password primary; role derived from record ──
  const login = async (email: string, password: string): Promise<{ error: string | null }> => {
    // ── Try Supabase RPC first ──────────────────────────────────
    try {
      const { data, error } = await supabase.rpc('authenticate_user_by_email', {
        login_email: email,
        login_password: password,
      });

      if (error) throw new Error(error.message);

      const payload = data as {
        auth_id: string;
        user_identifier: string;
        role: string;
        username: string;
        email: string;
        full_name?: string;
      };

      const session: StoredSession = {
        auth_id: payload.auth_id,
        user_id: payload.user_identifier,
        role: payload.role.toLowerCase(),
        email: payload.email || payload.username,
        full_name: payload.full_name || payload.username,
      };
      writeSession(session);

      setUser({ id: payload.auth_id, email: session.email! });
      setProfile({
        id: payload.user_identifier,
        email: session.email!,
        full_name: session.full_name!,
        role: session.role as UserRole,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

      return { error: null };

    } catch (rpcErr: any) {
      console.warn('[Auth] Supabase RPC failed, falling back to local mode:', rpcErr.message);
    }

    // ── Local offline fallback ────────────────────────────
    // SECURITY: Match on BOTH email AND password. Role is NEVER used for auth.
    // Role is read from the found record — the user cannot inject it.
    const users = getLocalUsers();
    const found = users.find(
      (u) => u.email.toLowerCase() === email.toLowerCase() && u.password === password
    );

    if (!found) {
      // Intentionally vague — never reveal which field was wrong
      return { error: 'Invalid credentials' };
    }

    // Role comes from the stored record, not from any user input
    const session: StoredSession = {
      auth_id: found.id,
      user_id: found.id,
      role: found.profile.role,
      email: found.email,
      full_name: found.profile.full_name,
    };
    writeSession(session);
    setUser({ id: found.id, email: found.email });
    setProfile(found.profile);

    return { error: null };
  };

  // ── Signup (disabled — managed staff app) ────────────────────
  const signup = async () => ({
    error: 'Registration is disabled. Contact the Hospital Administrator.',
  });

  // ── Logout — full session + window state wipe ─────────────────
  const logout = async () => {
    // 1. Destroy all open windows BEFORE clearing auth state.
    //    This prevents any split-second render of the previous user's panels.
    useWindowStore.getState().resetStore();

    // 2. Clear persisted session
    clearSession();

    // 3. Clear React state
    setUser(null);
    setProfile(null);
  };

  return (
    <AuthContext.Provider value={{ user, profile, loading, login, signup, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

// ─── Hook ────────────────────────────────────────────────────────
export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within <AuthProvider>');
  return ctx;
}
