with cte as
(
    select
        substring(Session_Title, 1, charindex('-', Session_Title)) as Id,
        Session_Title,
        isnull(Session_Abstract, '') as Session_Abstract,
        1 as ToUpdate
    from
        dbo.VSLIVE_ORIGINAL
)
insert into
    [web].[sessions] (external_id, title, abstract, require_embeddings_update)
select 
    case 
        when charindex('-', id) > 0 then substring(Id, 1, charindex('-', Session_Title) - 2) else '' end 
    as Id,
    Session_Title,
    Session_Abstract,
    ToUpdate
from
    cte
go

insert into web.speakers
    (full_name)
select distinct    
    trim(s2.[value]) as speaker
from
    dbo.VSLIVE_ORIGINAL o
cross apply
    string_split(speaker, ',') s
cross apply
    string_split(s.[value], '&') s2
where
    s2.[value] <> ''
go

with cte as
(
    select
        substring(Session_Title, 1, charindex('-', Session_Title)) as Id,
        Session_Title,
        Speaker
    from
        dbo.VSLIVE_ORIGINAL
), cte2 as
(
    select 
        case 
            when charindex('-', id) > 0 then substring(Id, 1, charindex('-', Session_Title) - 2) else '' end 
        as Id,
        trim(s2.[value]) as speaker
    from
        cte
    cross apply
        string_split(speaker, ',') s
    cross apply
        string_split(s.[value], '&') s2
    where
        s2.[value] <> ''
)
insert into web.sessions_speakers (session_id, speaker_id)
select distinct
    --c.*,
    s.id,
    sp.id
from
    cte2 c
inner join
    web.sessions s on c.Id = s.external_id collate Latin1_General_100_BIN2
inner join
    web.speakers sp on c.speaker = sp.full_name collate Latin1_General_100_BIN2