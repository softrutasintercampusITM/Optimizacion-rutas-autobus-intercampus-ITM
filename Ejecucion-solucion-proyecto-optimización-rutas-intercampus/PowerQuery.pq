let
    AzureMapsKey = "-----> aqui va tu apiKey, entre las comillas<-----",

    // Lista de coordenadas de inicio y fin en formato de registros
    CoordinatesList = {
        [Start = "6.27555,-75.58816", End = "6.24546,-75.54991"]
    },
    
     //Dia y hora
     departAt = "2024-06-14T17:00:00-05:00",
    

    // Función para obtener rutas para un par de coordenadas de inicio y fin
    GetRoutesForCoordinates = (coords) =>
        let
            StartLocation = coords[Start],
            EndLocation = coords[End],
            URL = "https://atlas.microsoft.com/route/directions/json?api-version=1.0&query=" & StartLocation & ":" & EndLocation & "&maxAlternatives=4&subscription-key=" & AzureMapsKey & "&departAt=" & departAt & "&constantSpeedConsumptionInLitersPerHundredkm=40,17",
            Source = Json.Document(Web.Contents(URL)),
            Routes = Source[routes],
        
            // Función para extraer las coordenadas y detalles de una ruta
            GetRouteTable = (route) =>
                let
                    Legs = route[legs],
                    FirstLeg = Legs{0},
                    Steps = FirstLeg[points],
                    RouteSteps = Table.FromList(Steps, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                    ExpandedSteps = Table.ExpandRecordColumn(RouteSteps, "Column1", {"latitude", "longitude"}, {"Latitude", "Longitude"}),
                    RenamedColumns = Table.RenameColumns(ExpandedSteps, {{"Latitude", "Latitud"}, {"Longitude", "Longitud"}}),

                    // Contar el número de puntos en la ruta
                    PointCount = Table.RowCount(ExpandedSteps),

                    // Añadir columnas de tiempo de viaje y distancia
                    TravelSummary = FirstLeg[summary],
                    TravelTimeTraffic = TravelSummary[travelTimeInSeconds],
                    TravelDistance = TravelSummary[lengthInMeters],
                    FuelConsumption = TravelSummary[fuelConsumptionInLiters], // Extraer consumo de gasolina

                    RouteWithTravelInfo = Table.AddColumn(RenamedColumns, "Tiempo Promedio (s)", each TravelTimeTraffic / PointCount),
                    RouteWithDistanceAndSpeed = Table.AddColumn(RouteWithTravelInfo, "Velocidad Promedio (m/s)", each TravelDistance / TravelTimeTraffic),
                    RouteWithDistanceSpeedAndGas = Table.AddColumn(RouteWithDistanceAndSpeed, "Consumo Prom de Gasolina (L)", each FuelConsumption / PointCount) // Ajustar según el valor real
                in
                    RouteWithDistanceSpeedAndGas,

            // Obtener tablas para cada ruta
            Route1Table = if List.Count(Routes) > 0 then GetRouteTable(Routes{0}) else null,
            Route2Table = if List.Count(Routes) > 1 then GetRouteTable(Routes{1}) else null,
            Route3Table = if List.Count(Routes) > 2 then GetRouteTable(Routes{2}) else null,
            Route4Table = if List.Count(Routes) > 3 then GetRouteTable(Routes{3}) else null,
            Route5Table = if List.Count(Routes) > 4 then GetRouteTable(Routes{4}) else null,

            // Añadir identificador de ruta
            Route1TableWithID = if Route1Table <> null then Table.AddColumn(Route1Table, "Ruta", each "Ruta 1") else null,
            Route2TableWithID = if Route2Table <> null then Table.AddColumn(Route2Table, "Ruta", each "Ruta 2") else null,
            Route3TableWithID = if Route3Table <> null then Table.AddColumn(Route3Table, "Ruta", each "Ruta 3") else null,
            Route4TableWithID = if Route4Table <> null then Table.AddColumn(Route4Table, "Ruta", each "Ruta 4") else null,
            Route5TableWithID = if Route5Table <> null then Table.AddColumn(Route5Table, "Ruta", each "Ruta 5") else null,

            // Combinar todas las tablas en una sola
            CombinedTable = Table.Combine(List.RemoveNulls({Route1TableWithID, Route2TableWithID, Route3TableWithID, Route4TableWithID, Route5TableWithID}))
        in
            CombinedTable,

    // Procesar cada par de coordenadas
    AllRoutesTables = List.Transform(CoordinatesList, each GetRoutesForCoordinates(_)),

    // Combinar todos los resultados en una sola tabla
    FinalCombinedTable = Table.Combine(AllRoutesTables),
    #"Filas filtradas" = Table.SelectRows(FinalCombinedTable, each true),
    #"Tipo cambiado" = Table.TransformColumnTypes(#"Filas filtradas",{{"Consumo Prom de Gasolina (L)", type text}})
in
    #"Tipo cambiado"
