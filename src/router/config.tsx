import type { RouteObject } from "react-router-dom";
import NotFound from "../pages/NotFound";
import Home from "../pages/home/page";
import ApplicationStatusPage from "../pages/application-status/page";
import PortalApp from "../portal/AppRoot";
import AuthPage from "../pages/auth/page";
import PublicCmsPage from "../pages/cms-detail/page";

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
    path: "/auth",
    element: <AuthPage />,
  },
  {
    path: "/portal/*",
    element: <PortalApp />,
  },
  {
    path: "/pages",
    element: <PublicCmsPage />,
  },
  {
    path: "/pages/:branchId/:slug",
    element: <PublicCmsPage />,
  },
  {
    path: "*",
    element: <NotFound />,
  },
];

export default routes;
