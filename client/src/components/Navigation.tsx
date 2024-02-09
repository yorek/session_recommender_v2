import { Divider, Tab, TabList } from "@fluentui/react-components";
import { SearchRegular, ChatRegular, InfoRegular } from "@fluentui/react-icons";
import { useNavigate } from "react-router-dom";

export const Navigation = () => {
  const navigate = useNavigate();

  return (
    <>
      <TabList
        onTabSelect={(_, data) => {
          navigate(data.value === "search" ? "/" : `/${data.value}`);
        }}
        selectedValue={
          window.location.pathname === "/"
            ? "search"
            : window.location.pathname.substring(1)
        }
      >
        <Tab id="search" value="search" icon={<SearchRegular />}>
          Search
        </Tab>
        <Tab id="chat" value="chat" icon={<ChatRegular />}>
          Chat
        </Tab>
        <Tab id="about" value="about" icon={<InfoRegular />}>
          About
        </Tab>
      </TabList>
      <div style={{ paddingBottom: "10px" }}></div>
      <Divider />
      <div style={{ paddingBottom: "20px" }}></div>
    </>
  );
};
