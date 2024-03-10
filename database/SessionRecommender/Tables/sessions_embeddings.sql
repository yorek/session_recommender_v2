CREATE TABLE [web].[sessions_embeddings] (
    [id]                INT              NOT NULL,
    [vector_value_id]   INT              NOT NULL,
    [vector_value]      DECIMAL (19, 16) NOT NULL,
    FOREIGN KEY ([id]) REFERENCES [web].[sessions] ([id])
);
GO

CREATE CLUSTERED COLUMNSTORE INDEX [IXCC]
    ON [web].[sessions_embeddings];
GO

