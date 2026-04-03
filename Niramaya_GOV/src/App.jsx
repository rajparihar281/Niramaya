import React from 'react';
import { BrowserRouter, Routes, Route, Link, useLocation } from 'react-router-dom';
import { Stethoscope, Activity, Users, AlertCircle, Radio, Wifi } from 'lucide-react';
import PatientView from './components/PatientView';
import DoctorView from './components/DoctorView';
import StaffView from './components/StaffView';
import EpidemicRadar from './components/EpidemicRadar';
import ConnectionStatus from './components/ConnectionStatus';

const Navbar = () => {
  const location = useLocation();
  const navItems = [
    { path: '/', label: 'Patient Booking', icon: Stethoscope },
    { path: '/staff', label: 'Staff / Reception', icon: Users },
    { path: '/doctor', label: 'Doctor Dashboard', icon: AlertCircle },
    { path: '/epidemic', label: 'Epidemic Radar', icon: Radio },
    { path: '/status', label: 'Status', icon: Wifi },
  ];

  return (
    <nav className="navbar">
      <div className="nav-brand">
        <Activity color="#0ea5e9" size={28} />
        Niramaya<span>Net</span>
      </div>
      <div className="nav-links">
        {navItems.map(({ path, label, icon: Icon }) => (
          <Link key={path} to={path} className={`nav-link ${location.pathname === path ? 'active' : ''}`}>
            <Icon size={18} style={{ display: 'inline', marginRight: '6px', verticalAlign: 'text-bottom' }} /> {label}
          </Link>
        ))}
      </div>
    </nav>
  );
};

const App = () => {
  return (
    <BrowserRouter>
      <div className="app-container animate-fade-in">
        <Navbar />
        <main className="main-content">
          <Routes>
            <Route path="/" element={<PatientView />} />
            <Route path="/staff" element={<StaffView />} />
            <Route path="/doctor" element={<DoctorView />} />
            <Route path="/epidemic" element={<EpidemicRadar />} />
            <Route path="/status" element={<ConnectionStatus />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  );
};

export default App;
