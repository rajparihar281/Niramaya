import { useState, useEffect, useRef } from 'react';

/**
 * AnimatedCounter — smoothly counts from previous value to the new value.
 * Uses requestAnimationFrame for buttery animation.
 * 
 * Props:
 *   value: number — target value
 *   duration: number — animation duration in ms (default 600)
 *   prefix: string — text before the number (e.g. '+')
 *   suffix: string — text after the number (e.g. '%')
 *   decimals: number — decimal places (default 0)
 */
const AnimatedCounter = ({ value, duration = 600, prefix = '', suffix = '', decimals = 0 }) => {
  const [display, setDisplay] = useState(value);
  const prevRef = useRef(value);
  const frameRef = useRef(null);

  useEffect(() => {
    const from = prevRef.current;
    const to = value;
    if (from === to) return;

    const start = performance.now();
    const diff = to - from;

    const animate = (now) => {
      const elapsed = now - start;
      const progress = Math.min(elapsed / duration, 1);
      // Ease-out cubic
      const eased = 1 - Math.pow(1 - progress, 3);
      setDisplay(from + diff * eased);

      if (progress < 1) {
        frameRef.current = requestAnimationFrame(animate);
      } else {
        prevRef.current = to;
      }
    };

    frameRef.current = requestAnimationFrame(animate);
    return () => { if (frameRef.current) cancelAnimationFrame(frameRef.current); };
  }, [value, duration]);

  const formatted = decimals > 0 ? display.toFixed(decimals) : Math.round(display);

  return <>{prefix}{formatted}{suffix}</>;
};

export default AnimatedCounter;
