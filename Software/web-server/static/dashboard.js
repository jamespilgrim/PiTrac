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
        document.getElementById('ws-status-dot').classList.remove('disconnected');
    };

    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        updateDisplay(data);
    };

    ws.onclose = () => {
        console.log('WebSocket disconnected');
        document.getElementById('ws-status-dot').classList.add('disconnected');
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

    // Update ball ready status indicator
    updateBallStatus(data.result_type, data.message);

    if (data.timestamp) {
        const date = new Date(data.timestamp);
        document.getElementById('timestamp').textContent = date.toLocaleTimeString();
    }

    // Update images - only show images for actual hits, clear for status messages
    const imageGrid = document.getElementById('image-grid');
    const resultType = (data.result_type || '').toLowerCase();
    
    // Only show images for hit results
    if (resultType.includes('hit') && data.images && data.images.length > 0) {
        imageGrid.innerHTML = data.images.map((img, idx) =>
            `<img src="/images/${img}" alt="Shot ${idx + 1}" class="shot-image" loading="lazy" onclick="openImage('${img}')">`
        ).join('');
    } else if (!resultType.includes('hit')) {
        imageGrid.innerHTML = '';
    }
}

function updateBallStatus(resultType, message) {
    const indicator = document.getElementById('ball-ready-indicator');
    const statusTitle = document.getElementById('ball-status-title');
    const statusMessage = document.getElementById('ball-status-message');
    
    indicator.classList.remove('initializing', 'waiting', 'stabilizing', 'ready', 'hit', 'error');
    
    if (resultType) {
        const normalizedType = resultType.toLowerCase();
        
        if (normalizedType.includes('initializing')) {
            indicator.classList.add('initializing');
            statusTitle.textContent = 'System Initializing';
            statusMessage.textContent = message || 'Starting up PiTrac system...';
        } else if (normalizedType.includes('waiting for ball')) {
            indicator.classList.add('waiting');
            statusTitle.textContent = 'Waiting for Ball';
            statusMessage.textContent = message || 'Please place ball on tee';
        } else if (normalizedType.includes('waiting for simulator')) {
            indicator.classList.add('waiting');
            statusTitle.textContent = 'Waiting for Simulator';
            statusMessage.textContent = message || 'Waiting for simulator to be ready';
        } else if (normalizedType.includes('pausing') || normalizedType.includes('stabilization')) {
            indicator.classList.add('stabilizing');
            statusTitle.textContent = 'Ball Detected';
            statusMessage.textContent = message || 'Waiting for ball to stabilize...';
        } else if (normalizedType.includes('ball ready') || normalizedType.includes('ready')) {
            indicator.classList.add('ready');
            statusTitle.textContent = 'Ready to Hit!';
            statusMessage.textContent = message || 'Ball is ready - take your shot!';
        } else if (normalizedType.includes('hit')) {
            indicator.classList.add('hit');
            statusTitle.textContent = 'Ball Hit!';
            statusMessage.textContent = message || 'Processing shot data...';
        } else if (normalizedType.includes('error')) {
            indicator.classList.add('error');
            statusTitle.textContent = 'Error';
            statusMessage.textContent = message || 'An error occurred';
        } else if (normalizedType.includes('multiple balls')) {
            indicator.classList.add('error');
            statusTitle.textContent = 'Multiple Balls Detected';
            statusMessage.textContent = message || 'Please remove extra balls';
        } else {
            statusTitle.textContent = 'System Status';
            statusMessage.textContent = message || resultType;
        }
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

async function checkSystemStatus() {
    try {
        const response = await fetch('/health');
        if (response.ok) {
            const data = await response.json();

            const mqDot = document.getElementById('mq-status-dot');
            if (data.activemq_connected) {
                mqDot.classList.remove('disconnected');
            } else {
                mqDot.classList.add('disconnected');
            }

            const pitracDot = document.getElementById('pitrac-status-dot');
            if (data.pitrac_running) {
                pitracDot.classList.remove('disconnected');
            } else {
                pitracDot.classList.add('disconnected');
            }
        }
    } catch (error) {
        console.error('Error checking system status:', error);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    initTheme();
    connectWebSocket();
    checkSystemStatus();

    setInterval(checkSystemStatus, 5000);

    const currentResultType = document.getElementById('result_type').textContent;
    const currentMessage = document.getElementById('message').textContent;
    updateBallStatus(currentResultType, currentMessage);

    document.addEventListener('visibilitychange', () => {
        if (!document.hidden && (!ws || ws.readyState !== WebSocket.OPEN)) {
            connectWebSocket();
        }
    });
});