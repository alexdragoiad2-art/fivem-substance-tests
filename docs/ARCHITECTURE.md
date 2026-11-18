# Architecture

## Consuming an item (server-authoritative)

```mermaid
sequenceDiagram
    participant P as Player (client)
    participant S as Server (corp.lua)
    participant DB as KVP storage
    P->>S: uses item (ESX usable item)
    S->>S: checks item count, creates one-time "pending use" token
    S-->>P: it_substante:consume(item)
    P->>P: progress bar + animation + prop (can be cancelled)
    P->>S: it_substante:consumed(item, ok)
    S->>S: validates token (same item, < 20 s), removes 1 item
    S->>S: alcohol -> stomach (pending) / drug -> effect + detection windows
    S->>DB: save body state
    S-->>P: it_substante:state(snapshot)
    P->>P: effects engine interpolates intensity smoothly
```

## Breathalyzer / drug test

```mermaid
sequenceDiagram
    participant O as Officer (client)
    participant S as Server (teste.lua)
    participant T as Tested person (client)
    participant DB as MySQL
    O->>S: uses device (on duty, cooldown checked)
    S->>S: finds nearest player (<= 2.5 m), opens session
    S-->>T: consent dialog (25 s)
    alt refuses / no answer
        T->>S: refuse (or timeout)
        S->>DB: INSERT verdict = 'refuz'
        S-->>O: legal notice (art. 337)
    else accepts
        T->>S: accept
        S-->>O: device UI + animation
        S-->>T: device UI
        S->>S: measures from the body model (+ device noise)
        S->>DB: INSERT result + verdict
        S-->>O: result + legal classification
        S-->>T: result
    end
```

## Body model

- Alcohol: `pending` (stomach) -> `bac` (blood), absorption 0.10 ‰/min, elimination 0.01 ‰/min, simulated in 1-minute steps.
- Breathalyzer: `mg/L = BAC / 2` (Romanian standard: 0.40 mg/L breath = 0.80 g/L blood).
- Drugs: each dose extends the effect window (capped) and resets the detection window (THC 120 min, meth 60 min).
