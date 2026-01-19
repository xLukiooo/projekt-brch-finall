import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

// Debug zmiennych środowiskowych React (tylko w development)
if (process.env.NODE_ENV === 'development') {
  console.log('🔧 Debug zmiennych środowiskowych React:');
  console.log('- REACT_APP_API_URL:', process.env.REACT_APP_API_URL);
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
