# Aether Grid — Design & Engineering Decisions

The brief said to make reasonable assumptions instead of asking questions.
Every assumption that affects behaviour, numbers or visuals is recorded here.

## 1. Product & scope

| # | Decision | Why |
|---|----------|-----|
| D1 | Portrait-only, dark-only, Android + iOS. | Matches the reference screens; a single tuned palette beats a diluted light theme. |
| D2 | **Mock-first**: `AppConfig.useMockDevice = true` by default. | The app must run end-to-end offline with no hardware. |
| D3 | The unit shown on screen is **kWh**, never `kW/h`. | `kW/h` in the references is a unit error (power per time). Intentional deviation. |
| D4 | Reference screens are treated as the pixel source of truth for the onboarding flow; everything else extends that language. | Brief. |

## 2. Simulator defaults (`lib/data/sources/mock`)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Node ID | `NEXUS-CORE-901` | From reference. |
| Link | `5.8 GHz Mesh` | From reference. |
| Capacity | 1,024 Wh | From reference. |
| Initial SoC | 84 % → ≈ 860 Wh | `stored = soc × capacity`. |
| Firmware | `v4.8.2-Aether` → update `v4.9.0-Aether` | |
| Microinverters | Roof A / B / C | Three, sharing the array output with small per-unit variance. |
| Solar curve | sunrise 06:40, peak 12:30, sunset 19:50, `sin^1.6` shape, peak ≈ 4.2 kW | Deterministic so screenshots and tests are repeatable. |
| Weather | 0.72–1.00 factor seeded from the date | Day-to-day variety without randomness between runs. |
| Home load | 330 W base + Gaussian bumps at 07:30, 13:00, 19:40, 22:00 | Typical European household shape. |
| Battery | 96 % one-way efficiency, 1.8 kW max charge, 2.0 kW max discharge | Plausible for a 1 kWh LFP pack. |
| Reserve | 20 % default, clamp 10–100 % | Backup Priority raises the floor to ≥ 80 %, Storm Guard to 100 %. |
| Month to date | 200 kWh harvested, 120 kWh exported | Matches the dashboard reference numbers on first launch. |
| Independence | the last 28 days are independent, day 29 is not | Gives a visible 28-day streak out of the box. |

A day is **independent** when grid import ≤ 5 % of home consumption.

## 3. Metrics (`lib/domain/metrics.dart`, unit-tested)

- Stored energy `= SoC × capacity`.
- Self-consumption `= (solar − export) ÷ solar`, clamped 0–100 %.
- Self-sufficiency `= (home − import) ÷ home`.
- Runtime estimate `= stored Wh ÷ rolling average home load` (last ~15 min).
- Battery health label: ≥ 90 % Optimal, ≥ 80 % Good, otherwise Service soon.
- State priority: fault > updating > offline > low reserve > island > charging/discharging > idle.

## 4. Money & carbon

| Assumption | Value |
|-----------|-------|
| Grid emission factor | **0.42 kg CO₂ / kWh** (EU-average order of magnitude) |
| Import tariff avoided | 0.28 / kWh |
| Export feed-in | 0.08 / kWh |
| Default currency | EUR (switchable: USD, GBP, TND) |

These are display estimates only and are labelled as such in the UI.

## 5. Visual system

- Fonts are **bundled** (`assets/google_fonts/`, Outfit, Manrope, JetBrains Mono) and runtime fetching is disabled, so the app looks identical offline and on first launch.
- The product photo was cut out to a transparent PNG (`aether_core.png`, 697 × 1280). The LED ring is measured at centre **(0.472, 0.390)** of the image and **0.181 × width** in diameter; `LedRingGlow` paints the live state colour exactly over it.
- LED ring follows state with colour **and** pattern: idle = mint breathe, charging = mint fill, discharging = mint double-pulse, island = amber breathe, low reserve = amber fast pulse, pairing = mint sweep, updating = white breathe, offline = grey steady, fault = red steady.
- Motion uses a small token set (`AppMotion`) and respects the OS reduce-motion setting.

## 6. Architecture

- Clean layering: `domain` (entities, metrics, repository interface) ← `data` (mock, BLE, live link sources) ← `features` (UI + controllers), wired with Riverpod.
- `ScenarioControl` is a separate interface, only implemented by the simulator, so debug hooks can never ship against real hardware.
- Pairing generates an **Ed25519 owner key** stored in secure storage; only the public key leaves the phone.
- BLE provisioning and the live WebSocket link are typed stubs with the same contract as the mock, so swapping is a provider change (see README).

## 7. Demo scenarios

Long-press the avatar on the dashboard to open the scenario sheet: trigger outage, restore grid, low reserve, firmware available, node offline, fast-forward 6 h, component gallery, reset demo.
