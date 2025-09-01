let ws = null;
let currentTheme = 'system';

function getSystemTheme() {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function applyTheme(theme) {
    const root = document.documentElement;
    
    root.removeAttribute('data-theme');
    
    document.querySelectorAll('.theme-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    
    if (theme === 'system') {
        const systemTheme = getSystemTheme();
        root.setAttribute('data-theme', systemTheme);
        document.querySelector('.theme-btn[data-theme="system"]').classList.add('active');
    } else {
        root.setAttribute('data-theme', theme);
        document.querySelector(`.theme-btn[data-theme="${theme}"]`).classList.add('active');
    }
}

function setTheme(theme) {
    currentTheme = theme;
    localStorage.setItem('pitrac-theme', theme);
    applyTheme(theme);
}

function initTheme() {
    const savedTheme = localStorage.getItem('pitrac-theme') || 'system';
    currentTheme = savedTheme;
    applyTheme(savedTheme);
}

window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (currentTheme === 'system') {
        applyTheme('system');
    }
});

function connectWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    ws = new WebSocket(`${protocol}//${window.location.host}/ws`);
    
    ws.onopen = () => {
        console.log('WebSocket connected');
        document.getElementById('status-dot').classList.remove('disconnected');
        document.getElementById('status-text').textContent = 'Connected';
    };
    
    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        updateDisplay(data);
    };
    
    ws.onclose = () => {
        console.log('WebSocket disconnected');
        document.getElementById('status-dot').classList.add('disconnected');
        document.getElementById('status-text').textContent = 'Disconnected';
        setTimeout(connectWebSocket, 3000);
    };
    
    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
    };
}

function updateDisplay(data) {
    const updateMetric = (id, value) => {
        const element = document.getElementById(id);
        const oldValue = element.textContent;
        if (oldValue !== value.toString()) {
            element.textContent = value;
            element.parentElement.classList.add('updated');
            setTimeout(() => {
                element.parentElement.classList.remove('updated');
            }, 500);
        }
    };
    
    updateMetric('speed', data.speed || '0.0');
    updateMetric('carry', data.carry || '0.0');
    updateMetric('launch_angle', data.launch_angle || '0.0');
    updateMetric('side_angle', data.side_angle || '0.0');
    updateMetric('back_spin', data.back_spin || '0');
    updateMetric('side_spin', data.side_spin || '0');
    
    document.getElementById('result_type').textContent = data.result_type || 'Waiting...';
    document.getElementById('message').textContent = data.message || '';
    
    if (data.timestamp) {
        const date = new Date(data.timestamp);
        document.getElementById('timestamp').textContent = 
            `Last update: ${date.toLocaleTimeString()}`;
    }
    
    if (data.images && data.images.length > 0) {
        const imageGrid = document.getElementById('image-grid');
        imageGrid.innerHTML = data.images.map((img, idx) => 
            `<img src="/images/${img}" alt="Shot ${idx + 1}" class="shot-image" loading="lazy" onclick="openImage('${img}')">`
        ).join('');
    }
}

function openImage(imgPath) {
    window.open(`/images/${imgPath}`, '_blank');
}

async function resetShot() {
    try {
        const response = await fetch('/api/reset', { method: 'POST' });
        if (response.ok) {
            console.log('Shot reset');
        }
    } catch (error) {
        console.error('Error resetting shot:', error);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    initTheme();
    connectWebSocket();
    
    document.addEventListener('visibilitychange', () => {
        if (!document.hidden && (!ws || ws.readyState !== WebSocket.OPEN)) {
            connectWebSocket();
        }
    });
});