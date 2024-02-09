import {
  Body1,
  Card,
  CardHeader,
  Textarea,
  TextareaProps,
  Text,
  makeStyles,
  CardFooter,
  Spinner,
  Title2
} from "@fluentui/react-components";
import { SendRegular } from "@fluentui/react-icons";
import { useState } from "react";
import { ActionFunctionArgs, useFetcher } from "react-router-dom";
import { ask } from "../api/chat";
import { FancyText } from "../components/FancyText";
import { PrimaryButton } from "../components/PrimaryButton";
import ReactMarkdown from "react-markdown";

var thinking = false

const useClasses = makeStyles({
  container: {},
  chatArea: {},
  answersArea: {marginTop: "1em"},
  textarea: { width: "100%", marginBottom: "1rem" },
});

export async function action({ request }: ActionFunctionArgs) {
  let formData = await request.formData();
  const prompt = formData.get("prompt");
  if (!prompt) {
    return null;
  }

  const data = await ask(prompt.toString());
  thinking = false
  return data;
}

const Answers = ({ data }: { data: Awaited<ReturnType<typeof action>> }) => {
  if (!data) {
    return null;
  }
  const components = [];
  
  var cid:number = 0
  for (const id in data) { cid = Number(id) }
  const [question, answer] = data[cid];    
      
  components.push(
    <Card key={cid}>        
      <Title2 as="h2" block={true} style={{ marginBottom: "3px", marginTop:"0px" }}>Your question</Title2>
      <FancyText>
        {question.question}
      </FancyText>
      <Title2 as="h2" block={true} style={{ marginBottom: "3px" }}>My answer</Title2>
      <FancyText>
        <ReactMarkdown>{answer.answer}</ReactMarkdown>
      </FancyText>
      <Title2 as="h2" block={true} style={{ marginBottom: "3px" }}>My thoughts</Title2>
      <FancyText>
        {answer.thoughts}
      </FancyText>
    </Card>
  );

  return <>{components}</>;
};

export const Chat = () => {
  const fetcher = useFetcher<Awaited<ReturnType<typeof action>>>();
  const classes = useClasses();

  const submitting = fetcher.state !== "idle";
  const data = fetcher.data;

  const [prompt, setPrompt] = useState("");

  const onChange: TextareaProps["onChange"] = (_, data) =>
    setPrompt(() => data.value);

  const onKeyDown: TextareaProps["onKeyDown"] = (e) => {
    if (!prompt) {
      return;
    }

    if (e.key === "Enter" && !e.shiftKey) {
      thinking = true      
      const formData = new FormData();
      formData.append("prompt", prompt);
      fetcher.submit(formData, { method: "POST" });      
    }
  };

  return (
    <div className={classes.container}>
      <div>
        <FancyText>
          Start a conversation and we'll recommend sessions for you to watch.
        </FancyText>        
      </div>
      <div className={classes.chatArea}>
        <fetcher.Form method="POST">
          <Textarea
            className={classes.textarea}
            resize="vertical"
            size="large"
            placeholder="Start chatting"
            name="prompt"
            id="prompt"
            disabled={submitting}
            onChange={onChange}
            value={prompt}
            onKeyDown={onKeyDown}
          ></Textarea>
          <PrimaryButton
            icon={<SendRegular />}
            disabled={submitting || !prompt}
          >
            Submit
          </PrimaryButton>
          {thinking && <Spinner label="Thinking..." />}
        </fetcher.Form>
      </div>
      <div className={classes.answersArea}>
        {!thinking && data && <Answers data={data} />}
      </div>
    </div>
  );
};
