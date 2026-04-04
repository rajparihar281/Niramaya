import { useState, useEffect, useRef } from 'react';
import { Clock, Radio } from 'lucide-react';

/**
 * LiveClock — real-time clock + system uptime counter.
 * Runs a 1-second interval to update both displays.
 */
const LiveClock = () => {
  const startRef = useRef(Date.now());
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(id);
  }, []);

  const elapsed = Math.floor((now.getTime() - startRef.current) / 1000);
  const hrs = String(Math.floor(elapsed / 3600)).padStart(2, '0');
  const mins = String(Math.floor((elapsed % 3600) / 60)).padStart(2, '0');
  const secs = String(elapsed % 60).padStart(2, '0');

  return (
    <div className="live-clock-strip">
      <div className="clock-item">
        <Clock size={10} />
        <span>{now.toLocaleTimeString('en-US', { hour12: false })}</span>
      </div>
      <div className="clock-divider" />
      <div className="clock-item clock-uptime">
        <Radio size={9} />
        <span>UPTIME {hrs}:{mins}:{secs}</span>
      </div>
      <div className="clock-divider" />
      <div className="clock-item">
        <span>{now.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }).toUpperCase()}</span>
      </div>
    </div>
  );
};

export default LiveClock;
