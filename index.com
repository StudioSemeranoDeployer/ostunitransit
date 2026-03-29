<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    <title>Ostuni Smart Transit Ultimate</title>
    
    <!-- Librerie -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">

    <style>
        :root {
            --l1-color: #0A58CA; --l2-color: #DC3545;
            --surface: rgba(255, 255, 255, 0.95); --bg: #f8f9fa;
            --text-main: #212529; --text-sub: #6C757D;
            --safe-top: env(safe-area-inset-top, 20px);
            --safe-bot: env(safe-area-inset-bottom, 20px);
        }

        * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { margin: 0; padding: 0; height: 100dvh; overflow: hidden; background: var(--bg); color: var(--text-main); }

        #map { position: absolute; top: 0; left: 0; right: 0; bottom: 0; z-index: 1; }

        /* HEADER */
        header {
            position: absolute; top: 0; left: 0; right: 0;
            padding: calc(var(--safe-top) + 10px) 20px 15px;
            background: linear-gradient(180deg, rgba(255,255,255,0.95) 0%, rgba(255,255,255,0.6) 100%);
            backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px);
            display: flex; justify-content: space-between; align-items: center; z-index: 1000;
        }
        .app-title { font-weight: 800; font-size: 20px; letter-spacing: -0.5px; }
        .app-title span { color: var(--l1-color); }
        .weather-badge { background: #f1f3f5; font-size: 12px; font-weight: 700; padding: 6px 12px; border-radius: 20px; color: var(--text-main); }

        /* BOTTONE GPS */
        .fab-gps {
            position: absolute; right: 15px; bottom: calc(360px + var(--safe-bot));
            width: 48px; height: 48px; border-radius: 50%; background: white; border: none;
            box-shadow: 0 4px 15px rgba(0,0,0,0.15); font-size: 20px; z-index: 1000; cursor: pointer;
        }

        /* BOTTOM SHEET */
        .bottom-sheet {
            position: absolute; bottom: 0; left: 0; right: 0;
            background: var(--surface); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);
            border-top-left-radius: 24px; border-top-right-radius: 24px;
            padding: 20px 15px calc(20px + var(--safe-bot)); z-index: 2000; box-shadow: 0 -10px 40px rgba(0,0,0,0.1);
        }

        .segmented-control { display: flex; background: rgba(0,0,0,0.05); border-radius: 12px; padding: 4px; margin-bottom: 12px; }
        .seg-btn { flex: 1; padding: 8px; border: none; border-radius: 8px; background: transparent; font-size: 12px; font-weight: 700; color: var(--text-sub); transition: 0.2s; }
        .seg-btn.active-l1 { background: white; color: var(--l1-color); box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .seg-btn.active-l2 { background: white; color: var(--l2-color); box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .seg-btn.active-dir { background: white; color: var(--text-main); box-shadow: 0 2px 5px rgba(0,0,0,0.1); }

        /* MAIN DASHBOARD INFO */
        .dashboard { display: flex; align-items: center; gap: 15px; margin-bottom: 15px; background: white; padding: 15px; border-radius: 16px; box-shadow: 0 2px 10px rgba(0,0,0,0.03); border: 1px solid rgba(0,0,0,0.05); }
        .timer-box { background: var(--text-main); color: white; min-width: 75px; height: 75px; border-radius: 16px; display: flex; flex-direction: column; justify-content: center; align-items: center; }
        .timer-box .val { font-size: 28px; font-weight: 800; line-height: 1; }
        .timer-box .lbl { font-size: 10px; font-weight: 700; text-transform: uppercase; opacity: 0.8; }
        .status-info { flex: 1; }
        .status-title { font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-sub); margin-bottom: 4px; }
        .status-text { font-size: 16px; font-weight: 800; color: var(--text-main); margin-bottom: 2px; }
        .live-status { font-size: 12px; font-weight: 600; color: #198754; display: flex; align-items: center; gap: 5px; }
        .live-dot { width: 8px; height: 8px; background: #198754; border-radius: 50%; animation: pulse 1.5s infinite; }

        /* SCORRIMENTO ORARI COMPLETI */
        .schedule-container { margin-bottom: 15px; }
        .schedule-title { font-size: 11px; font-weight: 800; color: var(--text-sub); margin-bottom: 8px; text-transform: uppercase; padding-left: 5px; }
        .schedule-scroller { display: flex; gap: 8px; overflow-x: auto; padding-bottom: 10px; scrollbar-width: none; -webkit-overflow-scrolling: touch; }
        .schedule-scroller::-webkit-scrollbar { display: none; }
        
        .time-chip { background: white; border: 1px solid #dee2e6; padding: 8px 14px; border-radius: 12px; font-size: 14px; font-weight: 700; color: var(--text-main); white-space: nowrap; }
        .time-chip.past { opacity: 0.4; background: #f8f9fa; text-decoration: line-through; }
        .time-chip.next { background: var(--l1-color); color: white; border-color: var(--l1-color); box-shadow: 0 4px 10px rgba(10, 88, 202, 0.3); transform: scale(1.05); }
        .time-chip.next-l2 { background: var(--l2-color); border-color: var(--l2-color); box-shadow: 0 4px 10px rgba(220, 53, 69, 0.3); }

        .btn-buy { display: block; width: 100%; padding: 15px; border-radius: 14px; background: var(--text-main); color: white; text-align: center; text-decoration: none; font-weight: 800; font-size: 14px; }

        /* MARKER MAPPA */
        .stop-marker { background: white; border: 3px solid #333; border-radius: 50%; box-shadow: 0 2px 5px rgba(0,0,0,0.3); }
        .bus-live-marker { background: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 20px; box-shadow: 0 4px 15px rgba(0,0,0,0.3); border: 2px solid var(--text-main); transition: transform 0.3s; z-index: 1000 !important; }

        @keyframes pulse { 0% { opacity: 1; transform: scale(0.9); } 50% { opacity: 0.5; transform: scale(1.1); } 100% { opacity: 1; transform: scale(0.9); } }
    </style>
</head>
<body>

<header>
    <div class="app-title">Ostuni<span>Transit</span></div>
    <div class="weather-badge" id="weather">☀️ --°C</div>
</header>

<div id="map"></div>
<button class="fab-gps" onclick="locateUser()">🎯</button>

<div class="bottom-sheet" id="ui-panel">
    <div class="segmented-control">
        <button id="tab-l1" class="seg-btn active-l1" onclick="appState.setLine('L1')">Linea 1 (Mare)</button>
        <button id="tab-l2" class="seg-btn" onclick="appState.setLine('L2')">Linea Specchia</button>
    </div>
    <div class="segmented-control" style="background: rgba(0,0,0,0.03);">
        <button id="dir-out" class="seg-btn active-dir" onclick="appState.setDir('out')">Verso Stazione</button>
        <button id="dir-in" class="seg-btn" onclick="appState.setDir('in')">Verso Centro</button>
    </div>

    <div class="dashboard">
        <div class="timer-box" id="timer-box">
            <span class="val" id="time-val">--</span>
            <span class="lbl">MIN</span>
        </div>
        <div class="status-info">
            <div class="status-title" id="lbl-dest">Prossima Corsa</div>
            <div class="status-text" id="next-time">--:--</div>
            <div class="live-status"><div class="live-dot" id="bus-dot"></div> <span id="bus-status">Ricerca bus...</span></div>
        </div>
    </div>

    <div class="schedule-container">
        <div class="schedule-title">Tutti gli orari di oggi</div>
        <div class="schedule-scroller" id="full-schedule">
            <!-- Generato da JS -->
        </div>
    </div>

    <a href="https://www.mooneygo.it/" class="btn-buy" id="btn-pay">🎟️ Acquista Ticket su MooneyGo</a>
</div>

<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
    const SCHEDULE_DB = {
        L1: {
            color: '#0A58CA', name: "Linea 1",
            out:["07:15", "08:05", "09:10", "10:10", "11:10", "12:10", "13:10", "14:10", "15:30", "16:40", "18:00", "19:10", "20:10"],
            in:["07:45", "08:35", "09:40", "10:40", "11:40", "12:40", "13:40", "14:40", "16:00", "17:10", "18:30", "19:40", "20:40"],
            route: [[40.7307, 17.5778],[40.7410, 17.5850],[40.7516, 17.5913],[40.7905, 17.5966]],
            labels: { out: "Da Centro ➔ Mare/Stazione", in: "Da Mare ➔ Centro" },
            travelTime: 20 // minuti stimati da capolinea a capolinea
        },
        L2: {
            color: '#DC3545', name: "L. Specchia",
            out:["06:55", "07:25", "08:15", "09:15", "10:15", "11:15", "12:15", "13:20", "14:20", "16:20", "17:30", "18:50", "19:50"],
            in:["07:10", "07:55", "08:50", "09:50", "10:50", "11:50", "12:50", "13:55", "15:00", "16:45", "18:10", "19:15", "20:15"],
            route: [[40.7350, 17.5710], [40.7450, 17.5800],[40.7516, 17.5913]],
            labels: { out: "Da V. Specchia ➔ Stazione", in: "Da Stazione ➔ V. Specchia" },
            travelTime: 15
        }
    };

    const appState = {
        line: 'L1', dir: 'out', map: null, 
        layers: { route: null, stops:[], bus: null, user: null },

        setLine(l) { this.line = l; this.updateUI(); this.drawMap(); },
        setDir(d) { this.dir = d; this.updateUI(); this.processData(); },

        updateUI() {
            const c = SCHEDULE_DB[this.line].color;
            document.getElementById('tab-l1').className = `seg-btn ${this.line === 'L1' ? 'active-l1' : ''}`;
            document.getElementById('tab-l2').className = `seg-btn ${this.line === 'L2' ? 'active-l2' : ''}`;
            document.getElementById('dir-out').className = `seg-btn ${this.dir === 'out' ? 'active-dir' : ''}`;
            document.getElementById('dir-in').className = `seg-btn ${this.dir === 'in' ? 'active-dir' : ''}`;
            document.getElementById('dir-out').innerText = SCHEDULE_DB[this.line].labels.out;
            document.getElementById('dir-in').innerText = SCHEDULE_DB[this.line].labels.in;
            document.getElementById('timer-box').style.background = c;
            document.getElementById('bus-dot').style.background = c;
            document.querySelector('.app-title span').style.color = c;
            
            this.processData();
        },

        processData() {
            const now = new Date();
            // TEST MODE: Rimuovi i commenti alle due righe sotto per simulare l'orario (es. 10:15 del mattino) e vedere il bus muoversi!
            // now.setHours(10);
            // now.setMinutes(15);
            
            const currentMins = now.getHours() * 60 + now.getMinutes();
            const schedule = SCHEDULE_DB[this.line][this.dir];
            
            let nextIndex = -1;
            let activeBusIndex = -1;

            // Analizza tutto il palinsesto
            for(let i=0; i<schedule.length; i++) {
                let [h, m] = schedule[i].split(':');
                let timeInMins = parseInt(h)*60 + parseInt(m);
                
                // Se l'orario della corsa è nel futuro
                if (timeInMins >= currentMins) {
                    if (nextIndex === -1) nextIndex = i;
                } else {
                    // Corsa nel passato. Vediamo se è ancora "in viaggio"
                    let arrivalTime = timeInMins + SCHEDULE_DB[this.line].travelTime;
                    if (currentMins < arrivalTime) {
                        activeBusIndex = i; // Trovato un bus attualmente in viaggio!
                    }
                }
            }

            this.renderFullSchedule(schedule, currentMins, nextIndex);
            
            // Logica Testo Info Dashboard
            if (nextIndex !== -1) {
                let [h, m] = schedule[nextIndex].split(':');
                let nextMins = parseInt(h)*60 + parseInt(m);
                document.getElementById('time-val').innerText = nextMins - currentMins;
                document.getElementById('next-time').innerText = schedule[nextIndex];
            } else {
                document.getElementById('time-val').innerText = "--";
                document.getElementById('next-time').innerText = "Fine Turno";
            }

            this.updateLiveBus(schedule, currentMins, activeBusIndex, nextIndex);
        },

        renderFullSchedule(schedule, currentMins, nextIndex) {
            const container = document.getElementById('full-schedule');
            container.innerHTML = '';
            
            let nextClass = this.line === 'L1' ? 'next' : 'next-l2';

            schedule.forEach((time, index) => {
                let div = document.createElement('div');
                div.innerText = time;
                
                if (index < nextIndex && nextIndex !== -1) {
                    div.className = 'time-chip past';
                } else if (index === nextIndex) {
                    div.className = `time-chip ${nextClass}`;
                    div.id = 'chip-next'; // Per l'autoscroll
                } else {
                    div.className = 'time-chip';
                }
                container.appendChild(div);
            });

            // Auto-scroll fluido al prossimo orario
            setTimeout(() => {
                const nextEl = document.getElementById('chip-next');
                if(nextEl) {
                    container.scrollTo({ left: nextEl.offsetLeft - 20, behavior: 'smooth' });
                }
            }, 300);
        },

        // CORE DELLA SIMULAZIONE VETTORIALE
        updateLiveBus(schedule, currentMins, activeBusIndex, nextIndex) {
            let statusText = document.getElementById('bus-status');
            let progress = 0; // da 0 a 1 lungo la rotta

            if (activeBusIndex !== -1) {
                // IL BUS È IN MOVIMENTO
                let [h, m] = schedule[activeBusIndex].split(':');
                let startMins = parseInt(h)*60 + parseInt(m);
                let passedMins = currentMins - startMins;
                progress = passedMins / SCHEDULE_DB[this.line].travelTime;
                statusText.innerText = "Bus in transito sulla rotta";
            } else if (nextIndex !== -1) {
                // IL BUS È FERMO AL CAPOLINEA IN ATTESA DELLA PARTENZA
                progress = 0; 
                let [h, m] = schedule[nextIndex].split(':');
                let diff = (parseInt(h)*60 + parseInt(m)) - currentMins;
                if(diff < 10) statusText.innerText = "Bus fermo al capolinea. Partenza imminente.";
                else statusText.innerText = "Bus in deposito/pausa.";
            } else {
                statusText.innerText = "Servizio giornaliero concluso.";
                if(this.layers.bus) this.map.removeLayer(this.layers.bus);
                return;
            }

            this.moveBusOnMap(progress);
        },

        moveBusOnMap(progress) {
            const rawRoute = SCHEDULE_DB[this.line].route;
            const path = this.dir === 'out' ? rawRoute : [...rawRoute].reverse();
            
            // Interpolazione geometrica lungo i segmenti della polilinea
            if (progress < 0) progress = 0;
            if (progress > 1) progress = 1;

            let totalSegments = path.length - 1;
            let scaledProgress = progress * totalSegments;
            let segmentIndex = Math.floor(scaledProgress);
            
            // Se siamo esattamente alla fine
            if (segmentIndex >= totalSegments) segmentIndex = totalSegments - 1; 

            let segmentProgress = scaledProgress - segmentIndex;
            let p1 = path[segmentIndex];
            let p2 = path[segmentIndex + 1];

            let lat = p1[0] + (p2[0] - p1[0]) * segmentProgress;
            let lng = p1[1] + (p2[1] - p1[1]) * segmentProgress;

            // Aggiorna o crea il marker del bus
            if (!this.layers.bus) {
                let icon = L.divIcon({ className: 'bus-live-marker', html: '🚌', iconSize:[38,38], iconAnchor:[19,19] });
                this.layers.bus = L.marker([lat, lng], {icon: icon, zIndexOffset: 1000}).addTo(this.map);
            } else {
                this.layers.bus.setLatLng([lat, lng]);
                this.layers.bus.getElement().style.borderColor = SCHEDULE_DB[this.line].color;
            }
        },

        initMap() {
            this.map = L.map('map', { zoomControl: false }).setView([40.7400, 17.5800], 14);
            L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png').addTo(this.map);
            this.drawMap();
            this.fetchWeather();
        },

        drawMap() {
            if(this.layers.route) this.map.removeLayer(this.layers.route);
            this.layers.stops.forEach(s => this.map.removeLayer(s));
            this.layers.stops =[];

            const c = SCHEDULE_DB[this.line].color;
            const route = SCHEDULE_DB[this.line].route;

            // Disegna rotta
            this.layers.route = L.polyline(route, { color: c, weight: 6, opacity: 0.8 }).addTo(this.map);

            // Disegna fermate
            const stopIcon = L.divIcon({ className: 'stop-marker', iconSize:[12, 12], iconAnchor: [6,6] });
            route.forEach(coords => {
                let m = L.marker(coords, { icon: stopIcon }).addTo(this.map);
                this.layers.stops.push(m);
            });

            // Centratura mappa che tiene conto del pannello UI in basso
            const uiHeight = document.getElementById('ui-panel').offsetHeight;
            this.map.fitBounds(this.layers.route.getBounds(), { paddingBottomRight:[20, uiHeight + 20], animate: true });
        },

        // API Meteo
        async fetchWeather() {
            try {
                let res = await fetch('https://api.open-meteo.com/v1/forecast?latitude=40.73&longitude=17.58&current_weather=true');
                let data = await res.json();
                document.getElementById('weather').innerText = `Ostuni: ${Math.round(data.current_weather.temperature)}°C`;
            } catch(e) {}
        }
    };

    function locateUser() {
        if (!appState.map) return;
        appState.map.locate({ setView: true, maxZoom: 16 });
    }

    window.onload = () => {
        appState.initMap();
        appState.updateUI();
        
        // Loop vitale: Aggiorna lo stato, i minuti e la posizione vettoriale del bus ogni 15 secondi
        setInterval(() => appState.processData(), 15000);
    };
</script>
</body>
</html>
