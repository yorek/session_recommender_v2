import * as React from "react";
import * as ReactDOM from "react-dom/client";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import "./index.css";

import Root from "./pages/Main";
import SessionSearch, { loader as sessionsListLoader } from "./pages/Search";
import { Chat, action as chatAction } from "./pages/Chat";
import {
  FluentProvider,
  Theme,
  webLightTheme,
} from "@fluentui/react-components";
import { About, loader as aboutLoader } from "./pages/About";

const router = createBrowserRouter([
  {
    path: "/",
    element: <Root />,
    children: [
      {
        index: true,
        element: <SessionSearch />,
        loader: sessionsListLoader,
      },
      {
        index: false,
        element: <Chat />,
        path: "/chat",
        action: chatAction,
      },
      {
        index: false,
        element: <About />,
        path: "/about",
        loader: aboutLoader,
      },
    ],
  },
]);

const lightTheme: Theme = {
  ...webLightTheme,
  colorNeutralBackground1: "transparent",
  colorBrandBackground: "var(--color-dotnet-solid-btn-accent-background)",
  colorBrandBackgroundHover: "var(--color-dotnet-solid-btn-accent-background)",
  fontFamilyBase: "var(--base-font-family)",
};

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <FluentProvider theme={lightTheme}>
      <RouterProvider router={router} />
    </FluentProvider>
  </React.StrictMode>
);
