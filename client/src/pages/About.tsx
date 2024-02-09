import { Suspense } from "react";
import { Await, LoaderFunction, defer, useLoaderData } from "react-router-dom";
import ls from "localstorage-slim";
import { getSessionsCount } from "../api/sessions";
import { FancyText } from "../components/FancyText";

function showSessionCount(
  sessionsCount: string | undefined | null = undefined
) {
  var sc = sessionsCount;
  if (sc === undefined) {
    sc = ls.get("sessionsCount");
  } else {
    ls.set("sessionsCount", sc, { ttl: 60 * 60 * 24 * 7 });
  }
  if (sc === undefined) {
    return <FancyText>Loading session count...</FancyText>;
  }
  return (
    <FancyText>
      There are{" "}
      <a href="https://www.dotnetconf.net/agenda">{sc} sessions indexed</a> so
      far.
    </FancyText>
  );
}

export const loader: LoaderFunction = async () => {
  const sessionsCount = getSessionsCount();
  return defer({ sessionsCount });
};

export const About = () => {
  const { sessionsCount } = useLoaderData() as {
    sessionsCount: string | number;
  };

  return (
    <>
      <FancyText>
        Source code and and related articles are{" "}
        <a href="https://github.com/Azure-Samples/azure-sql-db-session-recommender">
          available on GitHub.
        </a>
      </FancyText>
      <Suspense fallback={showSessionCount()}>
        <Await
          resolve={sessionsCount}
          errorElement={
            <FancyText>Unable to load session count 😥...</FancyText>
          }
        >
          {(sessionsCount) => showSessionCount(sessionsCount)}
        </Await>
      </Suspense>
    </>
  );
};
