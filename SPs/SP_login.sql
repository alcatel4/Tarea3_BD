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
                SET @DescripcionEvento = 'Fallido: Password incorrecto'
            END
            ELSE
            BEGIN
                SET @outResultCode = 0
                SET @IdTipoEvento = 1
                SET @DescripcionEvento = 'Exitoso'
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
        SET @outResultCode = 50008
    END CATCH
END