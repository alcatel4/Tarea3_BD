CREATE PROCEDURE dbo.procProcesarAsistencia
    @inValorDocumentoIdentidad VARCHAR(20)
    ,@inHoraEntrada DATETIME
    ,@inHoraSalida DATETIME
    ,@inFechaOperacion DATETIME
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    -- Variables de identificacion
    DECLARE @IdEmpleado INT
    DECLARE @IdPlanillaSemanal INT
    DECLARE @IdAsistencia INT
    DECLARE @IdHorarioJornada INT
    DECLARE @IdMovPlanilla INT
    DECLARE @IdUsuarioSistema INT

    -- Variables de calculo
    DECLARE @SalarioXHora MONEY
    DECLARE @HoraFinJornadaDT DATETIME
    DECLARE @HoraFinJornada DATETIME
    DECLARE @HorasOrdinarias DECIMAL(10,2)
    DECLARE @HorasExtraNormal DECIMAL(10,2)
    DECLARE @HorasExtraDoble DECIMAL(10,2)
    DECLARE @MontoOrdinario MONEY
    DECLARE @MontoExtraNormal MONEY
    DECLARE @MontoExtraDoble MONEY
    DECLARE @NuevoSaldo MONEY
    DECLARE @FechaSalida DATE
    DECLARE @Descripcion VARCHAR(256)

    -- Flags
    DECLARE @flagFechaExtraDoble BIT
    DECLARE @flagHayExtraNormal BIT
    DECLARE @flagHayExtraDoble BIT

    SET @outResultCode = 0
    SET @flagFechaExtraDoble = 0
    SET @flagHayExtraNormal = 0
    SET @flagHayExtraDoble = 0
    SET @HorasOrdinarias = 0
    SET @HorasExtraNormal = 0
    SET @HorasExtraDoble = 0
    SET @MontoOrdinario = 0
    SET @MontoExtraNormal = 0
    SET @MontoExtraDoble = 0

    BEGIN TRY

        -- Obtener usuario administrador del sistema para bitacora
        SELECT @IdUsuarioSistema = u.id
        FROM dbo.Usuario AS u
        WHERE (u.Tipo = 1)

        -- Obtener id del empleado y salario por hora segun su puesto
        SELECT @IdEmpleado = e.id
            ,@SalarioXHora = p.SalarioXHora
        FROM dbo.Empleado AS e
        INNER JOIN dbo.Puesto AS p ON (p.id = e.idPuesto)
        WHERE (e.DocumentoIdentidad = @inValorDocumentoIdentidad)

        IF (@IdEmpleado IS NULL)
        BEGIN
            SET @outResultCode = 50012
            RETURN
        END

        -- Obtener la planilla semanal activa del empleado para la fecha de operacion
        SELECT @IdPlanillaSemanal = ps.id
            ,@NuevoSaldo = ps.SalarioBruto
        FROM dbo.PlanillaSemanal AS ps
        INNER JOIN dbo.Semana AS s ON (s.id = ps.idSemana)
        WHERE (ps.idEmpleado = @IdEmpleado)
            AND (s.FechaInicio <= @inFechaOperacion)
            AND (s.FechaFin >= @inFechaOperacion)

        -- Obtener el horario de jornada asignado al empleado para esta semana
        SELECT @IdHorarioJornada = hj.id
            ,@HoraFinJornada = tj.HoraFin
        FROM dbo.HorarioJornada AS hj
        INNER JOIN dbo.TipoJornada AS tj ON (tj.id = hj.idTipoJornada)
        WHERE (hj.idPlanillaSemanal = @IdPlanillaSemanal)

        -- Calcular la hora exacta de fin de jornada basada en la fecha de entrada
        SET @HoraFinJornadaDT = DATEADD(
            MINUTE,
            DATEDIFF(MINUTE, '00:00:00', CAST(@HoraFinJornada AS TIME)),
            CAST(CAST(@inHoraEntrada AS DATE) AS DATETIME)
        )

        -- Si la hora fin queda antes o igual a la entrada, la jornada cruza medianoche
        IF (@HoraFinJornadaDT <= @inHoraEntrada)
            SET @HoraFinJornadaDT = DATEADD(DAY, 1, @HoraFinJornadaDT)

        -- Calcular horas ordinarias, solo horas completas
        IF (@inHoraSalida <= @HoraFinJornadaDT)
            SET @HorasOrdinarias = FLOOR(DATEDIFF(MINUTE, @inHoraEntrada, @inHoraSalida) / 60.0)
        ELSE
            SET @HorasOrdinarias = FLOOR(DATEDIFF(MINUTE, @inHoraEntrada, @HoraFinJornadaDT) / 60.0)

        -- Calcular horas extras si la salida supera el fin de jornada
        IF (@inHoraSalida > @HoraFinJornadaDT)
        BEGIN
            SET @FechaSalida = CAST(@HoraFinJornadaDT AS DATE)

            IF (DATEPART(WEEKDAY, @FechaSalida) = 1)
                SET @flagFechaExtraDoble = 1

            IF EXISTS (
                SELECT 1
                FROM dbo.Feriado AS f
                WHERE (CAST(f.Fecha AS DATE) = @FechaSalida)
            )
                SET @flagFechaExtraDoble = 1

            IF (@flagFechaExtraDoble = 1)
            BEGIN
                SET @HorasExtraDoble = FLOOR(DATEDIFF(MINUTE, @HoraFinJornadaDT, @inHoraSalida) / 60.0)
                SET @flagHayExtraDoble = 1
            END
            ELSE
            BEGIN
                SET @HorasExtraNormal = FLOOR(DATEDIFF(MINUTE, @HoraFinJornadaDT, @inHoraSalida) / 60.0)
                SET @flagHayExtraNormal = 1
            END
        END

        -- Calcular montos segun tipo de hora
        SET @MontoOrdinario = @HorasOrdinarias * @SalarioXHora
        SET @MontoExtraNormal = @HorasExtraNormal * @SalarioXHora * 1.5
        SET @MontoExtraDoble = @HorasExtraDoble * @SalarioXHora * 2.0

        -- Preparar descripcion para bitacora
        SET @Descripcion = '{"Empleado":"' + @inValorDocumentoIdentidad +
            '","FechaOperacion":"' + CAST(@inFechaOperacion AS VARCHAR) +
            '","HoraEntrada":"' + CAST(@inHoraEntrada AS VARCHAR) +
            '","HoraSalida":"' + CAST(@inHoraSalida AS VARCHAR) + '"}'

        BEGIN TRANSACTION

            -- Registrar la asistencia del empleado
            INSERT INTO dbo.Asistencia (
                Fecha
                ,MarcaInicio
                ,MarcaFin
                ,idEmpleado
                ,idHorarioJornada
            )
            VALUES (
                @inFechaOperacion
                ,@inHoraEntrada
                ,@inHoraSalida
                ,@IdEmpleado
                ,@IdHorarioJornada
            )

            SET @IdAsistencia = SCOPE_IDENTITY()

            -- Registrar movimiento de horas ordinarias
            SET @NuevoSaldo = @NuevoSaldo + @MontoOrdinario

            INSERT INTO dbo.MovPlanilla (
                Fecha
                ,Monto
                ,NuevoSaldo
                ,idPlanillaSemanal
                ,idTipoMov
            )
            VALUES (
                @inFechaOperacion
                ,@MontoOrdinario
                ,@NuevoSaldo
                ,@IdPlanillaSemanal
                ,1
            )

            SET @IdMovPlanilla = SCOPE_IDENTITY()

            INSERT INTO dbo.MovHoras (
                QHoras
                ,idMovPlanilla
                ,idAsistencia
            )
            VALUES (
                @HorasOrdinarias
                ,@IdMovPlanilla
                ,@IdAsistencia
            )

            -- Registrar movimiento de horas extras normales si las hay
            IF (@flagHayExtraNormal = 1)
            BEGIN
                SET @NuevoSaldo = @NuevoSaldo + @MontoExtraNormal

                INSERT INTO dbo.MovPlanilla (
                    Fecha
                    ,Monto
                    ,NuevoSaldo
                    ,idPlanillaSemanal
                    ,idTipoMov
                )
                VALUES (
                    @inFechaOperacion
                    ,@MontoExtraNormal
                    ,@NuevoSaldo
                    ,@IdPlanillaSemanal
                    ,2
                )

                SET @IdMovPlanilla = SCOPE_IDENTITY()

                INSERT INTO dbo.MovHoras (
                    QHoras
                    ,idMovPlanilla
                    ,idAsistencia
                )
                VALUES (
                    @HorasExtraNormal
                    ,@IdMovPlanilla
                    ,@IdAsistencia
                )
            END

            -- Registrar movimiento de horas extras dobles si las hay
            IF (@flagHayExtraDoble = 1)
            BEGIN
                SET @NuevoSaldo = @NuevoSaldo + @MontoExtraDoble

                INSERT INTO dbo.MovPlanilla (
                    Fecha
                    ,Monto
                    ,NuevoSaldo
                    ,idPlanillaSemanal
                    ,idTipoMov
                )
                VALUES (
                    @inFechaOperacion
                    ,@MontoExtraDoble
                    ,@NuevoSaldo
                    ,@IdPlanillaSemanal
                    ,3
                )

                SET @IdMovPlanilla = SCOPE_IDENTITY()

                INSERT INTO dbo.MovHoras (
                    QHoras
                    ,idMovPlanilla
                    ,idAsistencia
                )
                VALUES (
                    @HorasExtraDoble
                    ,@IdMovPlanilla
                    ,@IdAsistencia
                )
            END

            -- Actualizar salario bruto acumulado en la planilla semanal
            UPDATE dbo.PlanillaSemanal
            SET SalarioBruto = @NuevoSaldo
            WHERE (id = @IdPlanillaSemanal)

            -- Registrar evento en bitacora
            INSERT INTO dbo.BitacoraEvento (
                idTipoEvento
                ,IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
            )
            VALUES (
                22
                ,'127.0.0.1'
                ,GETDATE()
                ,@Descripcion
                ,@IdUsuarioSistema
            )

        COMMIT TRANSACTION

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
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
            @inValorDocumentoIdentidad
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