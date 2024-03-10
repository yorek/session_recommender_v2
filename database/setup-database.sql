if not exists(select * from sys.symmetric_keys where [name] = '##MS_DatabaseMasterKey##')
begin
    create master key encryption by password = N'V3RYStr0NGP@ssw0rd!';
end
GO

if exists(select * from sys.[database_scoped_credentials] where name = '$(OPEN_AI_ENDPOINT)')
begin
	drop database scoped credential [$(OPEN_AI_ENDPOINT)];
end
GO

create database scoped credential [$(OPEN_AI_ENDPOINT)]
with identity = 'HTTPEndpointHeaders', secret = '{"api-key":"$(OPEN_AI_KEY)"}';
GO

GO
PRINT N'Creating SqlUser [session_recommender_app]...';


GO
CREATE USER [session_recommender_app]
    WITH PASSWORD = N'$(APP_USER_PASSWORD)';


GO
REVOKE CONNECT TO [session_recommender_app];


GO
PRINT N'Creating SqlRoleMembership [db_owner] for [session_recommender_app]...';


GO
EXECUTE sp_addrolemember @rolename = N'db_owner', @membername = N'session_recommender_app';


GO
PRINT N'Creating SqlSchema [web]...';


GO
CREATE SCHEMA [web]
    AUTHORIZATION [dbo];


GO
PRINT N'Creating SqlTable [web].[speakers]...';


GO
CREATE TABLE [web].[speakers] (
    [id]                        INT            NOT NULL,
    [external_id]               VARCHAR (100)  COLLATE Latin1_General_100_BIN2 NULL,
    [full_name]                 NVARCHAR (100) NOT NULL,
    [require_embeddings_update] BIT            NOT NULL,
    [embeddings]                NVARCHAR (MAX) NULL,
    PRIMARY KEY CLUSTERED ([id] ASC),
    UNIQUE NONCLUSTERED ([full_name] ASC)
);


GO
PRINT N'Creating SqlTable [web].[sessions_speakers]...';


GO
CREATE TABLE [web].[sessions_speakers] (
    [session_id] INT NOT NULL,
    [speaker_id] INT NOT NULL,
    PRIMARY KEY CLUSTERED ([session_id] ASC, [speaker_id] ASC)
);


GO
PRINT N'Creating SqlIndex [web].[sessions_speakers].[ix2]...';


GO
CREATE NONCLUSTERED INDEX [ix2]
    ON [web].[sessions_speakers]([speaker_id] ASC);


GO
PRINT N'Creating SqlTable [web].[sessions]...';


GO
CREATE TABLE [web].[sessions] (
    [id]                        INT            NOT NULL,
    [title]                     NVARCHAR (200) NOT NULL,
    [abstract]                  NVARCHAR (MAX) NOT NULL,
    [external_id]               VARCHAR (100)  COLLATE Latin1_General_100_BIN2 NULL,
    [last_fetched]              DATETIME2 (7)  NULL,
    [start_time_PST]            DATETIME2 (0)  NULL,
    [end_time_PST]              DATETIME2 (0)  NULL,
    [tags]                      NVARCHAR (MAX) NULL,
    [recording_url]             VARCHAR (1000) NULL,
    [require_embeddings_update] BIT            NOT NULL,
    [embeddings]                NVARCHAR (MAX) NULL,
    PRIMARY KEY CLUSTERED ([id] ASC),
    UNIQUE NONCLUSTERED ([title] ASC)
);


GO
PRINT N'Creating SqlTable [web].[sessions_embeddings]...';


GO
CREATE TABLE [web].[sessions_embeddings] (
    [id]              INT              NOT NULL,
    [vector_value_id] INT              NOT NULL,
    [vector_value]    DECIMAL (19, 16) NOT NULL
);


GO
PRINT N'Creating SqlColumnStoreIndex [web].[sessions_embeddings].[IXCC]...';


GO
CREATE CLUSTERED INDEX [IXCC]
    ON [web].[sessions_embeddings]([id]);

CREATE CLUSTERED COLUMNSTORE INDEX [IXCC]
    ON [web].[sessions_embeddings] WITH (DROP_EXISTING = ON);


GO
PRINT N'Creating SqlTable [web].[searched_text]...';


GO
CREATE TABLE [web].[searched_text] (
    [id]               INT            IDENTITY (1, 1) NOT NULL,
    [searched_text]    NVARCHAR (MAX) NOT NULL,
    [search_datetime]  DATETIME2 (7)  NOT NULL,
    [ms_rest_call]     INT            NULL,
    [ms_vector_search] INT            NULL,
    [found_sessions]   INT            NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
);


GO
PRINT N'Creating SqlTable [web].[speakers_embeddings]...';


GO
CREATE TABLE [web].[speakers_embeddings] (
    [id]              INT              NOT NULL,
    [vector_value_id] INT              NOT NULL,
    [vector_value]    DECIMAL (19, 16) NOT NULL
);


GO
PRINT N'Creating SqlColumnStoreIndex [web].[speakers_embeddings].[IXCC]...';


GO
CREATE CLUSTERED INDEX [IXCC]
    ON [web].[speakers_embeddings]([id]);

CREATE CLUSTERED COLUMNSTORE INDEX [IXCC]
    ON [web].[speakers_embeddings] WITH (DROP_EXISTING = ON);


GO
PRINT N'Creating SqlDefaultConstraint unnamed constraint on [web].[speakers]...';


GO
ALTER TABLE [web].[speakers]
    ADD DEFAULT ((0)) FOR [require_embeddings_update];


GO
PRINT N'Creating SqlDefaultConstraint unnamed constraint on [web].[sessions]...';


GO
ALTER TABLE [web].[sessions]
    ADD DEFAULT ((0)) FOR [require_embeddings_update];


GO
PRINT N'Creating SqlDefaultConstraint unnamed constraint on [web].[searched_text]...';


GO
ALTER TABLE [web].[searched_text]
    ADD DEFAULT (sysdatetime()) FOR [search_datetime];


GO
PRINT N'Creating SqlSequence [web].[global_id]...';


GO
CREATE SEQUENCE [web].[global_id]
    AS INT
    START WITH 1
    INCREMENT BY 1;


GO
PRINT N'Creating SqlDefaultConstraint unnamed constraint on [web].[speakers]...';


GO
ALTER TABLE [web].[speakers]
    ADD DEFAULT (NEXT VALUE FOR [web].[global_id]) FOR [id];


GO
PRINT N'Creating SqlDefaultConstraint unnamed constraint on [web].[sessions]...';


GO
ALTER TABLE [web].[sessions]
    ADD DEFAULT (NEXT VALUE FOR [web].[global_id]) FOR [id];


GO
PRINT N'Creating SqlForeignKeyConstraint unnamed constraint on [web].[sessions_speakers]...';


GO
ALTER TABLE [web].[sessions_speakers]
    ADD FOREIGN KEY ([speaker_id]) REFERENCES [web].[speakers] ([id]);


GO
PRINT N'Creating SqlForeignKeyConstraint unnamed constraint on [web].[sessions_speakers]...';


GO
ALTER TABLE [web].[sessions_speakers]
    ADD FOREIGN KEY ([session_id]) REFERENCES [web].[sessions] ([id]);


GO
PRINT N'Creating SqlForeignKeyConstraint unnamed constraint on [web].[sessions_embeddings]...';


GO
ALTER TABLE [web].[sessions_embeddings]
    ADD FOREIGN KEY ([id]) REFERENCES [web].[sessions] ([id]);


GO
PRINT N'Creating SqlForeignKeyConstraint unnamed constraint on [web].[speakers_embeddings]...';


GO
ALTER TABLE [web].[speakers_embeddings]
    ADD FOREIGN KEY ([id]) REFERENCES [web].[speakers] ([id]);


GO
PRINT N'Creating SqlCheckConstraint unnamed constraint on [web].[speakers]...';


GO
ALTER TABLE [web].[speakers]
    ADD CHECK (isjson([embeddings])=(1));


GO
PRINT N'Creating SqlCheckConstraint unnamed constraint on [web].[sessions]...';


GO
ALTER TABLE [web].[sessions]
    ADD CHECK (isjson([tags])=(1));


GO
PRINT N'Creating SqlView [web].[search_stats]...';


GO
create view [web].search_stats
as
select 
    count(*) as total_searches, 
    avg(ms_vector_search) as avg_ms_vector_search 
from 
    [web].searched_text
GO
PRINT N'Creating SqlView [web].[last_searches]...';


GO
create view [web].last_searches
as
select top (100)
    id, 
    searched_text, 
    switchoffset(search_datetime, '-08:00') as search_datetime_pst, 
    ms_rest_call, 
    ms_vector_search, 
    found_sessions
from 
    [web].searched_text 
order by 
    id desc
GO
PRINT N'Creating SqlProcedure [web].[upsert_speaker_embeddings]...';


GO

create procedure [web].[upsert_speaker_embeddings]
@id int,
@embeddings nvarchar(max)
as

set xact_abort on
set transaction isolation level serializable

begin transaction

    delete from web.speakers_embeddings 
    where id = @id

    insert into web.speakers_embeddings
    select @id, cast([key] as int), cast([value] as float) 
    from openjson(@embeddings)

    update web.speakers set require_embeddings_update = 0 where id = @id

commit
GO
PRINT N'Creating SqlProcedure [web].[upsert_session_embeddings]...';


GO

create procedure [web].[upsert_session_embeddings]
@id int,
@embeddings nvarchar(max)
as

set xact_abort on
set transaction isolation level serializable

begin transaction

    delete from web.sessions_embeddings 
    where id = @id

    insert into web.sessions_embeddings
    select @id, cast([key] as int), cast([value] as float) 
    from openjson(@embeddings)

    update web.sessions set require_embeddings_update = 0 where id = @id

commit
GO
PRINT N'Creating SqlProcedure [web].[find_sessions]...';


GO
create procedure [web].[find_sessions]
@text nvarchar(max),
@top int = 10,
@min_similarity decimal(19,16) = 0.75
as
if (@text is null) return;

declare @sid as int = -1;
if (@text like N'***%') begin    
    set @text = trim(cast(substring(@text, 4, len(@text) - 3) as nvarchar(max)));    
end else begin
    insert into web.searched_text (searched_text) values (@text);
    set @sid = scope_identity();
end;

declare @startTime as datetime2(7) = sysdatetime()

declare @retval int, @response nvarchar(max);
declare @payload nvarchar(max);
set @payload = json_object('input': @text);

begin try
    exec @retval = sp_invoke_external_rest_endpoint
        @url = '$(OPEN_AI_ENDPOINT)/openai/deployments/$(OPEN_AI_DEPLOYMENT)/embeddings?api-version=2023-03-15-preview',
        @method = 'POST',
        @credential = [$(OPEN_AI_ENDPOINT)],
        @payload = @payload,
        @response = @response output;
end try
begin catch
    select 
        'SQL' as error_source, 
        error_number() as error_code,
        error_message() as error_message
    return;
end catch

if (@retval != 0) begin
    select 
        'OPENAI' as error_source, 
        json_value(@response, '$.result.error.code') as error_code,
        json_value(@response, '$.result.error.message') as error_message,
        @response as error_response
    return;
end;

declare @endTime1 as datetime2(7) = sysdatetime();
update [web].[searched_text] set ms_rest_call = datediff(ms, @startTime, @endTime1) where id = @sid;

with cteVector as
(
    select 
        cast([key] as int) as [vector_value_id],
        cast([value] as float) as [vector_value]
    from 
        openjson(json_query(@response, '$.result.data[0].embedding'))
),
cteSimilarSpeakers as 
(
    select 
        v2.id as speaker_id, 
        -- Optimized as per https://platform.openai.com/docs/guides/embeddings/which-distance-function-should-i-use
        sum(v1.[vector_value] * v2.[vector_value]) as cosine_similarity
    from 
        cteVector v1
    inner join 
        web.speakers_embeddings v2 on v1.vector_value_id = v2.vector_value_id
    group by
        v2.id

),
cteSimilar as
(
    select 
        v2.id as session_id, 
        -- Optimized as per https://platform.openai.com/docs/guides/embeddings/which-distance-function-should-i-use
        sum(v1.[vector_value] * v2.[vector_value]) as cosine_similarity
    from 
        cteVector v1
    inner join 
        web.sessions_embeddings v2 on v1.vector_value_id = v2.vector_value_id
    group by
        v2.id
        
    union all

    select
        ss.session_id,
        s.cosine_similarity
    from
        web.sessions_speakers ss 
    inner join
        cteSimilarSpeakers s on s.speaker_id = ss.speaker_id
),
cteSimilar2 as (
    select
        *,
        rn = row_number() over (partition by session_id order by cosine_similarity desc)
    from
        cteSimilar
),
cteSpeakers as
(
    select 
        session_id, 
        json_query('["' + string_agg(string_escape(full_name, 'json'), '","') + '"]') as speakers
    from 
        web.sessions_speakers ss 
    inner join 
        web.speakers sp on sp.id = ss.speaker_id 
    group by 
        session_id
)
select top(@top)
    a.id,
    a.title,
    a.abstract,
    a.external_id,
    a.start_time_PST,
    a.end_time_PST,
    a.recording_url,
    isnull((select top (1) speakers from cteSpeakers where session_id = a.id), '[]') as speakers,
    r.cosine_similarity
from 
    cteSimilar2 r
inner join 
    web.sessions a on r.session_id = a.id
where   
    r.cosine_similarity > @min_similarity
and
    rn = 1
order by    
    r.cosine_similarity desc, a.title asc;

declare @rc int = @@rowcount;

declare @endTime2 as datetime2(7) = sysdatetime()
update 
    [web].[searched_text] 
set 
    ms_vector_search = datediff(ms, @endTime1, @endTime2),
    found_sessions = @rc
where 
    id = @sid
GO
PRINT N'Creating SqlProcedure [web].[get_sessions_count]...';


GO
create procedure [web].[get_sessions_count]
as
select count(*) as total_sessions from [web].[sessions];
GO
-- This file contains SQL statements that will be executed after the build script.

alter table [web].[sessions] enable change_tracking with (track_columns_updated = off);
GO

alter table [web].[speakers] enable change_tracking with (track_columns_updated = off);
GO
