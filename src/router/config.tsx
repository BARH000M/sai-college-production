import type { RouteObject } from "react-router-dom";
import NotFound from "../pages/NotFound";
import Home from "../pages/home/page";
import ApplicationStatusPage from "../pages/application-status/page";
import PortalApp from "../portal/AppRoot";

const routes: RouteObject[] = [
  {
    path: "/",
    element: <Home />,
  },
  {
    path: "/application-status",
    element: <ApplicationStatusPage />,
  },
  {
    path: "/portal/*",
    element: <PortalApp />,
  },
  {
    path: "*",
    element: <NotFound />,
  },
];

export default routes;
