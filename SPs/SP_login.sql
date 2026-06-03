CREATE PROCEDURE dbo.procLogin
    @inUsername VARCHAR(64)
    ,@inPassword VARCHAR(64)
    ,@inPostInIP VARCHAR(64)
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdUsuario INT
    DECLARE @PassUsuario VARCHAR(64)
    DECLARE @IdTipoEvento INT
    DECLARE @DescripcionEvento VARCHAR(256)

    SET @outResultCode = 0

    BEGIN TRY

        SELECT @IdUsuario = u.Id
        FROM dbo.Usuario AS u
        WHERE (u.Username = @inUsername)

        IF (@IdUsuario IS NULL)
        BEGIN
            SET @outResultCode = 50001
        END
        ELSE
        BEGIN
            SELECT @PassUsuario = u.Password
            FROM dbo.Usuario AS u
            WHERE (u.Id = @IdUsuario)
                AND (u.Password = @inPassword)

            IF (@PassUsuario IS NULL)
            BEGIN
                SET @outResultCode = 50002
                SET @IdTipoEvento = 2
                SET @DescripcionEvento = @inUsername + ', No exitoso'
            END
            ELSE
            BEGIN
                SET @outResultCode = 0
                SET @IdTipoEvento = 1
                SET @DescripcionEvento = @inUsername + ', Exitoso'
            END

            INSERT INTO dbo.BitacoraEvento (
                idTipoEvento
                ,IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
            )
            VALUES (
                @IdTipoEvento
                ,@inPostInIP
                ,GETDATE()
                ,@DescripcionEvento
                ,@IdUsuario
            )
        END

    END TRY
    BEGIN CATCH

        INSERT INTO dbo.DBError (
            UserName
            ,Number
            ,State
            ,Severity
            ,Line
            ,[Procedure]
            ,Message
            ,DateTime
        )
        VALUES (
            @inUsername
            ,ERROR_NUMBER()
            ,ERROR_STATE()
            ,ERROR_SEVERITY()
            ,ERROR_LINE()
            ,ERROR_PROCEDURE()
            ,ERROR_MESSAGE()
            ,GETDATE()
        )

        SET @outResultCode = 50008

    END CATCH
END