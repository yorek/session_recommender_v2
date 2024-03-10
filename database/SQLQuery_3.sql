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
GO


with cte as (
    SELECT        
        [Session_Title],[Date],[Time],
        CHARINDEX(',', [Date], 1) as [CommaIndex],
        [Date2] = Parse([Date] + ', 2024 ' + TRIM([TimeSplit].[value]) as datetime2 using 'en-us')
    FROM 
        [dbo].[VSLIVE_ORIGINAL]
    cross apply 
        string_split([Time], '-') as [TimeSplit]  
), cte2 as
(
    select 
        [Session_Title], [starts] = min(Date2), [ends] = max(date2)
    from 
        cte
    group by [Session_Title]
)
update 
    s 
set
    s.[start_time_PST] = c.[starts],
    s.[end_time_PST] = c.[ends]
from 
    web.sessions s
inner join
    cte2 c on s.[title] = c.[Session_Title]