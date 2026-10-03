import { useId, useState } from 'react';
import { defaultProfile, parseProfile, type DiscoveryProfile } from '../shared/discovery';
import { categories } from '../shared/types';
import { categoryNames } from './lib';

const storageKey = 'wagz.discovery.preferences.v1';
const audienceOptions: Array<{ value: DiscoveryProfile['audience']; label: string }> = [
  { value: 'all', label: 'Za sve' },
  { value: 'students', label: 'Studenti i mladi' },
  { value: 'adults', label: 'Odrasli' },
  { value: 'seniors', label: 'Stariji' },
];

export function readPreferences(): DiscoveryProfile {
  try {
    return parseProfile(JSON.parse(localStorage.getItem(storageKey) ?? 'null'));
  } catch {
    return parseProfile(null);
  }
}

export function savePreferences(preferences: DiscoveryProfile) {
  try {
    localStorage.setItem(storageKey, JSON.stringify(preferences));
  } catch {
    // Personalization still works for this visit when browser storage is unavailable.
  }
}

export function Preferences({
  value,
  onChange,
}: {
  value: DiscoveryProfile;
  onChange: (preferences: DiscoveryProfile) => void;
}) {
  const [open, setOpen] = useState(false);
  const id = useId();
  const personalized = value.audience !== 'all' || value.interests.length > 0;
  const summary = [
    value.audience === 'all'
      ? null
      : audienceOptions.find((option) => option.value === value.audience)?.label,
    ...value.interests.map((category) => categoryNames[category]),
  ]
    .filter(Boolean)
    .join(' · ');

  return (
    <div className={`preferences ${open ? 'preferences-open' : ''}`}>
      <div className="preferences-summary">
        <div>
          <h3>Tvoj pogled na grad.</h3>
          <p>{personalized ? summary : 'Odaberi publiku i interese za svoje prijedloge.'}</p>
        </div>
        <button
          className="preferences-toggle"
          aria-expanded={open}
          aria-controls={`${id}-options`}
          onClick={() => setOpen(!open)}
        >
          {open ? 'Zatvori odabir' : personalized ? 'Promijeni odabir' : 'Prilagodi sebi'}
          <span aria-hidden="true">{open ? '−' : '+'}</span>
        </button>
      </div>
      {open && (
        <div className="preferences-options" id={`${id}-options`}>
          <p className="preferences-explanation">
            Ističemo programe za odabranu publiku i tvoje interese. Svi događaji ostaju u pregledu.
          </p>
          <fieldset>
            <legend>Za koga tražiš plan?</legend>
            <div className="audience-options">
              {audienceOptions.map((option) => (
                <label
                  key={option.value}
                  className={`audience-choice ${value.audience === option.value ? 'active' : ''}`}
                >
                  <input
                    type="radio"
                    name={`${id}-audience`}
                    value={option.value}
                    checked={value.audience === option.value}
                    onChange={() => onChange({ ...value, audience: option.value })}
                  />
                  {option.label}
                </label>
              ))}
            </div>
          </fieldset>
          <fieldset>
            <legend>
              Tvoji interesi <span>odaberi koliko želiš</span>
            </legend>
            <div className="interest-options">
              {categories.map((category) => (
                <button
                  key={category}
                  className={`interest-chip ${value.interests.includes(category) ? 'active' : ''}`}
                  aria-pressed={value.interests.includes(category)}
                  onClick={() =>
                    onChange({
                      ...value,
                      interests: value.interests.includes(category)
                        ? value.interests.filter((interest) => interest !== category)
                        : [...value.interests, category],
                    })
                  }
                >
                  <span aria-hidden="true">{value.interests.includes(category) ? '✓' : '+'}</span>
                  {categoryNames[category]}
                </button>
              ))}
            </div>
          </fieldset>
          <div className="preferences-footer">
            <p>Bez prijave. Odabir ostaje samo u ovom pregledniku.</p>
            {personalized && (
              <button className="text-button" onClick={() => onChange(defaultProfile)}>
                Poništi odabir
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
