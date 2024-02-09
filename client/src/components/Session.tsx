import { SessionInfo } from "../api/sessions";
import { formatSubtitle } from "../pages/Search";
import { Text, Title2 } from "@fluentui/react-components";
import { FancyText } from "./FancyText";

export const Session = ({ session }: { session: SessionInfo }) => {
  return (
    <div key={session.external_id}>
      <Title2 as="h2" block={true} style={{ marginBottom: "3px" }}>
        <a href={"https://www.dotnetconf.net/agenda#" + session.external_id}>
          {session.title}
        </a>
      </Title2>
      <Text className="session-similarity" weight="bold" size={400}>
        {formatSubtitle(session)}
      </Text>
      <FancyText weight="semibold" size={500} className="abstract">
        {session.abstract}
      </FancyText>
    </div>
  );
};
