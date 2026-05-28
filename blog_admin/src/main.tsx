import React from 'react';
import ReactDOM from 'react-dom/client';
import { createBrowserRouter, RouterProvider } from 'react-router-dom';

import { App } from './App';
import './styles.css';

const appName = import.meta.env.VITE_APP_NAME;
const uiBasePath = import.meta.env.VITE_UI_BASE_PATH;

const router = createBrowserRouter(
  [
    {
      path: '*',
      element: <App />
    }
  ],
  {
    basename: `/ords/${uiBasePath}/ui/${appName}`
  }
);

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>
);
