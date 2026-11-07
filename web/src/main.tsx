import React, { lazy, Suspense } from "react";
import ReactDOM from "react-dom/client";
import { ErrorBoundary } from "./components/ErrorBoundary";
import "./styles.css";

const App = lazy(() => import("./App"));
const root = document.getElementById("root");
if (!root) throw new Error("The application root element is missing.");

ReactDOM.createRoot(root).render(
  <React.StrictMode>
    <ErrorBoundary>
      <Suspense fallback={<main className="centered" role="status">جارٍ تحميل التطبيق...</main>}>
        <App />
      </Suspense>
    </ErrorBoundary>
  </React.StrictMode>
);
