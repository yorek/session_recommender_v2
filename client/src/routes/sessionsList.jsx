import { useEffect } from "react";
import { Form, json, useLoaderData, useNavigation, } from "react-router-dom";
import { getSessions } from "../sessions";
import dayjs from 'dayjs';

export async function loader({ request }) {
    const url = new URL(request.url);
    const searchQuery = url.searchParams.get("q") ?? "";
    var isSearch = (searchQuery == "") ? false : true;
    var { sessions, errorInfo } = isSearch ? await getSessions(searchQuery) : {sessions:[], errorInfo:null};
    if (!Array.isArray(sessions)) { 
        errorInfo = { errorMessage: "Error: sessions is not an array" };
        sessions = [];
    }
    return { sessions, searchQuery, isSearch, errorInfo };
}

export default function SessionsList() {
    const { sessions, searchQuery, isSearch, errorInfo } = useLoaderData();
    const navigation = useNavigation();

    const searching =
        navigation.location &&
        new URLSearchParams(navigation.location.search).has(
            "q"
        );

    useEffect(() => {
        document.getElementById("q").value = searchQuery;
    }, [searchQuery]);

    return (
        <>
            <div id="searchbox">
                <div>
                    <Form id="search-form" role="search">
                        <input
                            id="q"
                            className={searching ? "loading" : ""}
                            aria-label="Search sessions"
                            placeholder="Search"
                            type="search"
                            name="q"
                            defaultValue={searchQuery}
                        />
                        <div id="search-spinner" aria-hidden hidden={!searching} />
                        <div className="sr-only" aria-live="polite"></div>
                        <button type="submit">Search</button>
                    </Form>
                </div>
            </div>
            <div id="sessions" className={navigation.state === "loading" ? "loading" : ""}>
                {errorInfo ? <p id="error"><i>{"[Error] Status: " + errorInfo.errorCode + " Message: " + errorInfo.errorMessage}</i></p> : ""}
                {sessions.length ? (
                    <section className="agenda-group">
                        {sessions.map((session) => (
                            <div key={session.external_id}>
                                <p className="font-title-2"><a href={"https://www.dotnetconf.net/agenda#"+session.external_id}>{session.title}</a></p>
                                <p className="session-similarity font-stronger">{formatSubtitle(session)}</p>
                                <p className="font-subtitle-2 abstract">
                                    {session.abstract}
                                </p>
                            </div>
                        ))}
                    </section>
                ) : (
                    <center><p><i>{ isSearch ? "No session found" : "" }</i></p></center>
                )}
            </div>
        </>
    );
}

function formatSubtitle(session) {
    var startTime = dayjs(session.start_time_PST)
    var endTime = dayjs(session.end_time_PST)

    var day = 3 - (16 - startTime.date());
    var start = startTime.format('hh:mm A');
    var end = endTime.format('hh:mm A');
    var speakers = JSON.parse(session.speakers).map(speaker => speaker).join(", ");

    return (
        <>
        {speakers} | <a href={session.recording_url} target="_blank">Recording</a> | Similarity: {session.cosine_similarity.toFixed(6)}         
        </>
    )
}