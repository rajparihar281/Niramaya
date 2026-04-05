import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';
import type { UserRole } from '@/types';
import {
  Card,
  Input,
  Button,
  Label,
  Select,
  Spinner,
  MessageBar,
  MessageBarBody,
} from '@fluentui/react-components';
import {
  PersonRegular,
  LockClosed24Regular,
  Mail24Regular,
} from '@fluentui/react-icons';

const ROLES: { value: UserRole; label: string }[] = [
  { value: 'admin', label: 'Administrator' },
  { value: 'doctor', label: 'Doctor' },
  { value: 'receptionist', label: 'Receptionist' },
  { value: 'pharmacist', label: 'Pharmacist' },
];

export default function Signup() {
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<UserRole>('doctor');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const { signup } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    const { error: err } = await signup(email, password, fullName, role);
    setLoading(false);

    if (err) {
      setError(err);
    } else {
      navigate('/');
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-page__bg" />
      <Card className="auth-card">
        <div className="auth-card__header">
          <span className="auth-card__icon">🏥</span>
          <h1 className="auth-card__title">Create Account</h1>
          <p className="auth-card__subtitle">Join Niramaya HMS</p>
        </div>

        {error && (
          <MessageBar intent="error">
            <MessageBarBody>{error}</MessageBarBody>
          </MessageBar>
        )}

        <form onSubmit={handleSubmit} className="auth-form">
          <div className="auth-form__field">
            <Label htmlFor="signup-name">Full Name</Label>
            <Input
              id="signup-name"
              value={fullName}
              onChange={(_, d) => setFullName(d.value)}
              contentBefore={<PersonRegular />}
              placeholder="Dr. Sharma"
              required
            />
          </div>

          <div className="auth-form__field">
            <Label htmlFor="signup-email">Email</Label>
            <Input
              id="signup-email"
              type="email"
              value={email}
              onChange={(_, d) => setEmail(d.value)}
              contentBefore={<Mail24Regular />}
              placeholder="doctor@niramaya.in"
              required
            />
          </div>

          <div className="auth-form__field">
            <Label htmlFor="signup-password">Password</Label>
            <Input
              id="signup-password"
              type="password"
              value={password}
              onChange={(_, d) => setPassword(d.value)}
              contentBefore={<LockClosed24Regular />}
              placeholder="••••••••"
              required
            />
          </div>

          <div className="auth-form__field">
            <Label htmlFor="signup-role">Role</Label>
            <Select
              id="signup-role"
              value={role}
              onChange={(_, d) => setRole(d.value as UserRole)}
            >
              {ROLES.map((r) => (
                <option key={r.value} value={r.value}>
                  {r.label}
                </option>
              ))}
            </Select>
          </div>

          <Button
            type="submit"
            appearance="primary"
            className="auth-form__submit"
            disabled={loading}
            icon={loading ? <Spinner size="tiny" /> : undefined}
          >
            {loading ? 'Creating…' : 'Create Account'}
          </Button>
        </form>

        <p className="auth-card__footer">
          Already have an account?{' '}
          <Link to="/login" className="auth-link">
            Sign in
          </Link>
        </p>
      </Card>
    </div>
  );
}
