import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';
import {
  Card, Input, Button, Label, Spinner,
  MessageBar, MessageBarBody,
} from '@fluentui/react-components';
import { MailRegular, LockClosed24Regular } from '@fluentui/react-icons';

const ROLES = [
  { id: 'admin', label: 'Admin', icon: '💼' },
  { id: 'doctor', label: 'Doctor', icon: '⚕️' },
  { id: 'reception', label: 'Receptionist', icon: '💁' },
  { id: 'pharma', label: 'Pharmacist', icon: '💊' },
];

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [selectedRole, setSelectedRole] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [shake, setShake] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleRoleSelect = (role: typeof ROLES[0]) => {
    setSelectedRole(role.id);
    setError(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedRole) {
      setError('Please select a role to sign in.');
      setShake(true);
      setTimeout(() => setShake(false), 400);
      return;
    }
    
    setError(null);
    setShake(false);
    setLoading(true);

    const { error: err } = await login(email.trim().toLowerCase(), password);
    setLoading(false);

    if (err) {
      setError(err);
      setShake(true);
      setTimeout(() => setShake(false), 400); // Remove class securely
    } else {
      navigate('/');
    }
  };

  return (
    <div className="auth-page animate-fade-in">
      <div className="auth-page__bg" />
      <Card className={`auth-card ${shake ? 'animate-shake' : ''}`}>
        <div className="auth-card__header">
          <span className="auth-card__icon">🏥</span>
          <h1 className="auth-card__title">Niramaya OS</h1>
          <p className="auth-card__subtitle">Secure Core System Access</p>
        </div>

        {error && (
          <MessageBar intent="error" style={{ marginBottom: 20 }}>
            <MessageBarBody>{error}</MessageBarBody>
          </MessageBar>
        )}

        <div className="role-selector">
          <div className="role-selector__title">Select Access Level</div>
          <div className="role-selector__grid">
            {ROLES.map((r) => (
              <div
                key={r.id}
                className={`role-card ${selectedRole === r.id ? 'is-selected' : ''}`}
                onClick={() => handleRoleSelect(r)}
              >
                <div className="role-card__icon">{r.icon}</div>
                <span>{r.label}</span>
              </div>
            ))}
          </div>
        </div>

        <form onSubmit={handleSubmit} className="auth-form">
          <div className="auth-form__field">
            <Label htmlFor="login-email">Email / ID</Label>
            <Input
              id="login-email"
              type="email"
              value={email}
              onChange={(_, d) => { setEmail(d.value); }}
              contentBefore={<MailRegular />}
              placeholder="Select a role or type manually…"
              required
            />
          </div>
          <div className="auth-form__field">
            <Label htmlFor="login-password">System Password</Label>
            <Input
              id="login-password"
              type="password"
              value={password}
              onChange={(_, d) => { setPassword(d.value); }}
              contentBefore={<LockClosed24Regular />}
              placeholder="••••••••"
              required
            />
          </div>
          <Button
            type="submit"
            size="large"
            className="auth-form__submit"
            disabled={loading || !email || !password || !selectedRole}
            icon={loading ? <Spinner size="tiny" /> : undefined}
          >
            {loading ? 'Authenticating…' : 'Initialize Session'}
          </Button>
        </form>

      </Card>
    </div>
  );
}
