import React, { useState, useEffect } from 'react';
import axios from 'axios';

// --- Konfiguracja Axios ---
// Ustaw bazowy URL dla zapytań API
const api = axios.create({
  baseURL: process.env.REACT_APP_API_URL
    ? process.env.REACT_APP_API_URL + '/api'
    : (process.env.NODE_ENV === 'development'
        ? 'http://127.0.0.1:8000/api'
        : '/api'), // TEMPORARY FIX: Direct EC2 connection
});

// Debug API URL
console.log('🔗 API Base URL:', api.defaults.baseURL);
console.log('🌍 Environment:', process.env.NODE_ENV);
console.log('🔧 REACT_APP_API_URL:', process.env.REACT_APP_API_URL);

function App() {
  const [items, setItems] = useState([]);
  const [newItemName, setNewItemName] = useState('');
  const [loading, setLoading] = useState(true);
  const [apiMessage, setApiMessage] = useState('');

  const fetchItems = () => {
    setLoading(true);
    console.log('📡 Fetching items from:', api.defaults.baseURL + '/items/');
    api.get('/items/')
      .then(response => {
        console.log('✅ Items fetched successfully:', response.data);
        setItems(response.data);
        setLoading(false);
      })
      .catch(error => {
        console.error('❌ Error fetching data:', error);
        console.error('Response status:', error.response?.status);
        console.error('Response data:', error.response?.data);
        setLoading(false);
      });
  };

  // Pobierz dane przy pierwszym renderowaniu
  useEffect(() => {
    fetchItems();
  }, []);

  // Funkcja do obsługi wysyłania formularza
  const handleSubmit = (event) => {
    event.preventDefault();
    if (!newItemName.trim()) return;

    console.log('📝 Adding new item:', newItemName);
    api.post('/items/', { name: newItemName })
    .then(() => {
      console.log('✅ Item added successfully');
      setNewItemName(''); // Wyczyść pole formularza
      fetchItems(); // Odśwież listę
    })
    .catch(error => {
      console.error('❌ Error adding item:', error);
      console.error('Response status:', error.response?.status);
      console.error('Response data:', error.response?.data);
    });
  };

  // Funkcja do testowania innego endpointu
  const fetchHello = () => {
    console.log('👋 Fetching hello message from:', api.defaults.baseURL + '/hello/');
    api.get('/hello/')
      .then(response => {
        console.log('✅ Hello message received:', response.data);
        setApiMessage(response.data.message);
      })
      .catch(error => {
        console.error('❌ Error fetching hello:', error);
        console.error('Response status:', error.response?.status);
        console.error('Response data:', error.response?.data);
        setApiMessage('Error fetching message.');
      });
  };

  return (
    <div style={{ maxWidth: '700px', margin: '50px auto', fontFamily: 'sans-serif', padding: '20px', border: '1px solid #ddd', borderRadius: '10px', boxShadow: '0 2px 10px rgba(0,0,0,0.1)' }}>
      <h1 style={{ textAlign: 'center' }}>React + Django</h1>

      <form onSubmit={handleSubmit} style={{ display: 'flex', marginBottom: '20px' }}>
        <input
          type="text"
          value={newItemName}
          onChange={(e) => setNewItemName(e.target.value)}
          placeholder="Enter new item name"
          style={{ flexGrow: 1, padding: '10px', fontSize: '16px' }}
        />
        <button type="submit" style={{ padding: '10px 20px', fontSize: '16px' }}>Add Item</button>
      </form>

      <div style={{ border: '1px solid #ccc', borderRadius: '5px' }}>
        <h2 style={{ textAlign: 'center', padding: '10px', borderBottom: '1px solid #ccc', margin: 0 }}>Items in Database</h2>
        {loading ? (
          <p style={{ textAlign: 'center', padding: '20px' }}>Loading...</p>
        ) : (
          <ul style={{ listStyle: 'none', margin: 0, padding: '10px' }}>
            {items.map(item => (
              <li key={item.id} style={{ padding: '10px', borderBottom: '1px solid #eee' }}>
                {item.name}
              </li>
            ))}
            {items.length === 0 && <p style={{ textAlign: 'center'}}>No items found. Add one!</p>}
          </ul>
        )}
      </div>

      <div style={{ marginTop: '20px', textAlign: 'center' }}>
        <button onClick={fetchHello} style={{ padding: '10px 20px' }}>Fetch Hello Message</button>
        {apiMessage && <p style={{ marginTop: '10px', fontStyle: 'italic' }}>Backend says: "{apiMessage}"</p>}
      </div>
    </div>
  );
}

export default App;
