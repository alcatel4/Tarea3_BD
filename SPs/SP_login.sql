CREATE PROCEDURE dbo.procLogin
    @inUsername VARCHAR(64)  --Username del usuario
    ,@inPassword VARCHAR(64)  --Password del usuario
    ,@inPostInIP VARCHAR(64)  --IP de origen del login
    ,@outTipoUsuario INT OUTPUT
    ,@outResultCode   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdUsuario INT
    DECLARE @PassUsuario VARCHAR(64)
    DECLARE @IdTipoEvento INT
    DECLARE @DescripcionEvento VARCHAR(256)

    SET @outResultCode = 0
    SET @outTipoUsuario = 0

    BEGIN TRY

        SELECT @IdUsuario = u.Id
        FROM dbo.Usuario AS u
        WHERE (u.Username = @inUsername)

        IF (@IdUsuario IS NULL) --Comprueba que el usuario exista
        BEGIN
            SET @outResultCode = 50001
            RETURN
        END

        SELECT @PassUsuario = u.Password
        FROM dbo.Usuario AS u
        WHERE (u.Id = @IdUsuario) 
            AND (u.Password = @inPassword)

        IF (@PassUsuario IS NULL) 
        BEGIN
            SET @outResultCode = 50002
            SET @IdTipoEvento = 2
            SET @DescripcionEvento = 'Fallido: Password incorrecto'
            SET @outTipoUsuario = 0
        END
        ELSE
        BEGIN
            SET @outResultCode = 0
            SET @IdTipoEvento = 1
            SET @DescripcionEvento = 'Exitoso'

            SELECT @outTipoUsuario = u.Tipo
            FROM dbo.Usuario AS u
            WHERE u.Id = @IdUsuario
        END

            SELECT @outTipoUsuario AS TipoUsuario,@outResultCode AS ResultCode
        BEGIN TRANSACTION

            INSERT INTO dbo.BitacoraEvento (
                IdTipoEvento
                ,IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
                ,idTipoEvento
            )
            VALUES (
                @IdTipoEvento
                ,@inPostInIP
                ,GETDATE()
                ,@DescripcionEvento
                ,@IdUsuario
                ,@IdTipoEvento
                
            )

        COMMIT TRANSACTION

    END TRY
    BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION

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