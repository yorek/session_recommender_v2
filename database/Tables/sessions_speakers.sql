CREATE TABLE [web].[sessions_speakers] (
    [session_id] INT NOT NULL,
    [speaker_id] INT NOT NULL,
    PRIMARY KEY CLUSTERED ([session_id] ASC, [speaker_id] ASC),
    FOREIGN KEY ([session_id]) REFERENCES [web].[sessions] ([id]),
    FOREIGN KEY ([speaker_id]) REFERENCES [web].[speakers] ([id])
);
GO


CREATE NONCLUSTERED INDEX [ix2]
    ON [web].[sessions_speakers]([speaker_id] ASC);
GO

