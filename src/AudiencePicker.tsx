import { parseProfile, type DiscoveryProfile } from '../shared/discovery';

const storageKey = 'wagz.discovery.preferences.v1';
const audiences: Array<{ value: DiscoveryProfile['audience']; label: string }> = [
  { value: 'all', label: 'Svi' },
  { value: 'students', label: 'Studenti' },
  { value: 'adults', label: 'Odrasli' },
  { value: 'seniors', label: 'Stariji' },
];

export function readPreferences(): DiscoveryProfile {
  try {
    const profile = parseProfile(JSON.parse(localStorage.getItem(storageKey) ?? 'null'));
    return { audience: profile.audience, interests: [] };
  } catch {
    return { audience: 'all', interests: [] };
  }
}

export function savePreferences(preferences: DiscoveryProfile) {
  try {
    localStorage.setItem(
      storageKey,
      JSON.stringify({ audience: preferences.audience, interests: [] }),
    );
  } catch {
    // The selection still works for this visit when storage is unavailable.
  }
}

export function AudiencePicker({
  value,
  onChange,
}: {
  value: DiscoveryProfile;
  onChange: (preferences: DiscoveryProfile) => void;
}) {
  return (
    <div className="audience-picker">
      <div className="audience-heading">
        <span className="eyebrow" id="audience-heading">
          ZA KOGA JE PLAN?
        </span>
        <span>Jedan odabir. Cijeli grad ostaje tu.</span>
      </div>
      <div className="audience-segments" role="group" aria-labelledby="audience-heading">
        {audiences.map((option) => (
          <button
            key={option.value}
            aria-pressed={value.audience === option.value}
            onClick={() => onChange({ audience: option.value, interests: [] })}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}
