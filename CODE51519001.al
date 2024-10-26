codeunit 51519001 WMSIntegrations
{

    trigger OnRun()
    begin
        // TODO
        /*
            1. Make a get call to fetch production order from API   
            2. Create a production order in Business Central 
        */
        getProductionOrderFromAPI();
    end;

    var
        HttpClient: HttpClient;

    procedure getProductionOrderFromAPI(): Text;
    var
        HttpResponseMessage: HttpResponseMessage;
        ResponseText: Text;
        APIUrl: Text;
        APIBaseUrl: Text;
    begin
        APIBaseUrl := 'http://100.100.2.39:3000/';
        APIUrl := APIBaseUrl + 'fetch-production-orders'; // Replace with your API URL


        if HttpClient.Get(APIUrl, HttpResponseMessage) then begin
            if HttpResponseMessage.IsSuccessStatusCode() then begin
                HttpResponseMessage.Content().ReadAs(ResponseText);
                // Process the response text
                // Message(ResponseText);
                exit(ResponseText);
            end else begin
                Error('Failed to fetch production order. Status Code: %1', HttpResponseMessage.HttpStatusCode());
            end;
        end else begin
            Error('Error making GET request.');
        end;
    end;



    procedure GetValue(JsonObj: JsonObject; JsonKey: Text; var Value: Variant)
    var
        JsonToken: JsonToken;
        TextValue: Text;
        DecimalValue: Decimal;
        BooleanValue: Boolean;
    begin
        if JsonObj.Get(JsonKey, JsonToken) then begin
            if JsonToken.IsValue() then begin
                // Write JSON token to Text and remove surrounding quotes, if any
                JsonToken.WriteTo(TextValue);
                TextValue := DelChr(TextValue, '<>', '"'); // Remove starting and ending double quotes

                // Check for boolean (true/false) by comparing text value
                if TextValue = 'true' then begin
                    BooleanValue := true;
                    Value := Format(BooleanValue);
                end else if TextValue = 'false' then begin
                    BooleanValue := false;
                    Value := Format(BooleanValue);
                end
                // Check if it's a number by attempting to evaluate it as a Decimal
                else
                    if Evaluate(DecimalValue, TextValue) then
                        Value := Format(DecimalValue, 0, 9) // Format number without thousand separator
                                                            // Otherwise, assume it's a text value
                    else
                        Value := TextValue;
            end else
                Error('Unsupported JSON token type for key %1', JsonKey);
        end else
            Error('Key %1 not found in JSON object', JsonKey);
    end;





    procedure ProcessProductionOrders(JsonResponse: Text)
    var
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        ProductionOrder: JsonObject;
        ProductionLine: JsonObject;
        ProductionJournalLinesArray: JsonArray;
        VariantValue: Variant; // Intermediate Variant variable for GetValue

        ProductionOrderNo, ItemNo, UOM, LocationCode, Bin, User, RoutingCode : Text;
        DateTimeStr: Text;
        Quantity: Decimal;
    begin
        // Parse the JSON response as an array
        if JsonArray.ReadFrom(JsonResponse) then begin
            foreach JsonToken in JsonArray do begin
                // Check if JsonToken is a JsonObject
                if JsonToken.IsObject() then begin
                    ProductionOrder := JsonToken.AsObject();

                    // Use GetValue with VariantValue and then assign to the appropriate variables
                    GetValue(ProductionOrder, 'production_order_no', VariantValue);
                    ProductionOrderNo := VariantValue;

                    GetValue(ProductionOrder, 'ItemNo', VariantValue);
                    ItemNo := VariantValue;

                    GetValue(ProductionOrder, 'Quantity', VariantValue);
                    Quantity := VariantValue;

                    GetValue(ProductionOrder, 'uom', VariantValue);
                    UOM := VariantValue;

                    GetValue(ProductionOrder, 'LocationCode', VariantValue);
                    LocationCode := VariantValue;

                    GetValue(ProductionOrder, 'BIN', VariantValue);
                    Bin := VariantValue;

                    GetValue(ProductionOrder, 'user', VariantValue);
                    User := VariantValue;

                    GetValue(ProductionOrder, 'routing', VariantValue);
                    RoutingCode := VariantValue;

                    GetValue(ProductionOrder, 'date_time', VariantValue);
                    DateTimeStr := VariantValue;

                    // Create the production order
                    if CreateProductionOrder(ProductionOrderNo, ItemNo, Quantity, UOM, LocationCode, Bin, User, RoutingCode, DateTimeStr) then begin
                        // Retrieve ProductionJournalLines array and process each line
                        if ProductionOrder.Get('ProductionJournalLines', JsonToken) then begin
                            if JsonToken.IsArray() then begin
                                ProductionJournalLinesArray := JsonToken.AsArray();
                                foreach JsonToken in ProductionJournalLinesArray do begin
                                    if JsonToken.IsObject() then begin
                                        ProductionLine := JsonToken.AsObject();
                                        CreateProductionJournalLine(ProductionOrderNo, ProductionLine, false);
                                    end;
                                end;
                            end;
                        end;

                        // Create routing and component lines for the production order
                        // CreateRoutingAndComponents(ProductionOrderNo, RoutingCode, ItemNo);
                    end;
                end;
            end;
        end
        else
            Error('Failed to parse JSON response.');
    end;


    local procedure EvaluateDate(DateStr: Text): Date
    var
        TempDate: Date;
    begin
        Evaluate(TempDate, DateStr);
        exit(TempDate);
    end;

    local procedure EvaluateTime(TimeStr: Text): Time
    var
        TempTime: Time;
    begin
        Evaluate(TempTime, TimeStr);
        exit(TempTime);
    end;


    procedure CreateProductionOrder(ProductionOrderNo: Text; ItemNo: Text; Quantity: Decimal; UOM: Text; LocationCode: Text; Bin: Text; User: Text; RoutingCode: Text; DateTimeStr: Text): Boolean
    var
        ProdOrderRec: Record "Production Order"; // Assume this is the table for production orders
        DatePart: Text;
        TimePart: Text;
        DateComponent: Date;
        TimeComponent: Time;
        ProductionJnlMgt: Codeunit "Production Journal Mgt";
        CalcProdOrder: Codeunit "Calculate Prod. Order";
        CreateOrderLine: Codeunit "Create Prod. Order Lines";
        ProductionOrderLine: Record "Prod. Order Line";


    begin

        DatePart := CopyStr(DateTimeStr, 1, 10); // Extract "2024-10-26"
        TimePart := CopyStr(DateTimeStr, 12, 8); // Extract "01:34:21"

        // Convert to Date and Time data types

        ProdOrderRec.Init();
        ProdOrderRec."No." := '';
        ProdOrderRec."Description 2" := ProductionOrderNo;
        ProdOrderRec.Validate("Source Type", ProdOrderRec."Source Type"::Item);
        ProdOrderRec.Validate("Source No.", Format(ItemNo));
        ProdOrderRec.Validate(Quantity, Quantity);
        ProdOrderRec."Location Code" := LocationCode;
        ProdOrderRec.Status := ProdOrderRec.Status::Released;
        ProdOrderRec.Validate("Creation Date", Today);
        ProdOrderRec."Starting Time" := EvaluateTime(TimePart);
        ProdOrderRec."Due Date" := EvaluateDate(DatePart);
        ProdOrderRec."Starting Date" := EvaluateDate(DatePart);

        // ProdOrderRec."Starting Time" := Time;

        // ProdOrderRec."Due Date" := Today;
        // ProdOrderRec."Starting Date" := Today;
        ProdOrderRec.Insert(true);
        ProdOrderRec."Description 2" := ProductionOrderNo;
        ProdOrderRec.Modify(true);

        CreateOrderLine.Copy(ProdOrderRec, 1, '', false);

        // Report.Run(Report::"Refresh Production Order", false, true, ProdOrderRec);
        //Message('Production Order %1 created successfully.', ProductionOrderNo);
        exit(true);
    end;

    procedure resolveProductionOrder(ProductionOrderNo: Text): Text

    var
        ProdOrderRec: Record "Production Order";
    begin
        ProdOrderRec.SetRange("Description 2", ProductionOrderNo);

        if ProdOrderRec.FindFirst() then
            exit(ProdOrderRec."No.")
        else
            Error('Production Order %1 not found.', ProductionOrderNo);

    end;

    local procedure resolveOrderLineNo(ProductionOrderNo: Text; ItemNo: Text): Integer
    var
        ProdOrderRec: Record "Prod. Order Line";
    begin
        ProdOrderRec.SetRange("Prod. Order No.", ProductionOrderNo);
        ProdOrderRec.SetRange("Item No.", ItemNo);
        if ProdOrderRec.FindFirst() then
            exit(ProdOrderRec."Line No.")
        else
            exit(0);
    end;



    procedure CreateProductionJournalLine(ProductionOrderNo: Text; ProductionLine: JsonObject; Output: Boolean)
    var
        ProdJournalRec: Record "Item Journal Line"; // Assume this is the table for journal lines
        ProdJournalRec2: Record "Item Journal Line"; // Assume this is the table for journal lines
        VariantValue: Variant; // Intermediate Variant variable for GetValue
        ItemNo, UOM, LocationCode, Bin, User, DateTimeStr : Text;
        Quantity: Decimal;
        LineNo: Integer;
        ProdOrderRec: Record "Production Order";
        Itemrec: Record Item;
        JournalBatchRec: Record "Item Journal Batch";
        JournalTemplateRec: Record "Item Journal Template";
        OrderLineNo: Integer;
    begin

        ProdOrderRec.SetRange("Description 2", ProductionOrderNo);
        // Use GetValue to retrieve each property from the JSON object
        GetValue(ProductionLine, 'ItemNo', VariantValue);
        ItemNo := VariantValue;



        GetValue(ProductionLine, 'Quantity', VariantValue);
        Quantity := VariantValue;

        GetValue(ProductionLine, 'uom', VariantValue);
        UOM := VariantValue;

        GetValue(ProductionLine, 'LocationCode', VariantValue);
        LocationCode := VariantValue;

        GetValue(ProductionLine, 'BIN', VariantValue);
        Bin := VariantValue;

        GetValue(ProductionLine, 'line_no', VariantValue);
        LineNo := VariantValue;

        GetValue(ProductionLine, 'user', VariantValue);
        User := VariantValue;

        GetValue(ProductionLine, 'date_time', VariantValue);
        DateTimeStr := VariantValue;


        // Initialize and populate the production journal line record
        ProdJournalRec.Init();

        if not (JournalTemplateRec.Get('OUTPUT')) then begin
            JournalTemplateRec."Name" := 'OUTPUT';
            JournalTemplateRec."Type" := JournalTemplateRec."Type"::Output;
            JournalTemplateRec."Description" := 'Output Journal Template';
            JournalTemplateRec.Insert(true);
        end;

        if not (JournalTemplateRec.Get('CONSUMP')) then begin
            JournalTemplateRec."Name" := 'CONSUMP';
            JournalTemplateRec."Type" := JournalTemplateRec."Type"::Consumption;
            JournalTemplateRec."Description" := 'Consumption Journal Template';
            JournalTemplateRec.Insert(true);
        end;

        if not (JournalBatchRec.Get('OUTPUT', 'OUTPUT')) then begin
            JournalBatchRec."Name" := 'OUTPUT';
            JournalBatchRec."Journal Template Name" := 'OUTPUT';
            JournalBatchRec."Template Type" := JournalBatchRec."Template Type"::Output;
            JournalBatchRec."Description" := 'Output Journal Batch';
            JournalBatchRec.Insert(true);
        end;

        if not (JournalBatchRec.Get('CONSUMP', 'CONSUMP')) then begin
            JournalBatchRec."Name" := 'CONSUMP';
            JournalBatchRec."Journal Template Name" := 'CONSUMP';
            JournalBatchRec."Template Type" := JournalBatchRec."Template Type"::Consumption;
            JournalBatchRec."Description" := 'Production Journal Batch';
            JournalBatchRec.Insert(true);
        end;




        ProdJournalRec."Document No." := ProductionOrderNo;
        ProdJournalRec.Validate("Item No.", ItemNo);
        ProdJournalRec.Validate("Posting Date", Today);

        if Itemrec.Get(ItemNo) then
            ProdOrderRec.Validate("Gen. Prod. Posting Group", Itemrec."Gen. Prod. Posting Group");
        ProdJournalRec."Document Type" := ProdJournalRec."Document Type"::" ";
        if (Output) then begin
            ProdJournalRec."Entry Type" := ProdJournalRec."Entry Type"::Output;
            ProdJournalRec.Validate("Journal Template Name", 'OUTPUT');
            ProdJournalRec.Validate("Journal Batch Name", 'OUTPUT');
        end
        else begin
            ProdJournalRec."Entry Type" := ProdJournalRec."Entry Type"::Consumption;
            ProdJournalRec.Validate("Journal Template Name", 'CONSUMP');
            ProdJournalRec.Validate("Journal Batch Name", 'CONSUMP');
        end;
        ProdJournalRec.Validate("Order Type", ProdJournalRec."Order Type"::Production);


        OrderLineNo := resolveOrderLineNo(ProductionOrderNo, ItemNo);
        if (OrderLineNo <> 0) then begin
            ProdJournalRec.Validate("Order No.", resolveProductionOrder(ProductionOrderNo));
            ProdJournalRec.Validate("Order Line No.", resolveOrderLineNo(ProductionOrderNo, ItemNo));
        end;


        ProdJournalRec.Validate("Unit of Measure Code", UOM);
        ProdJournalRec.Validate(Quantity, Quantity);
        ProdJournalRec.Validate("Line No.", LineNo);
        ProdJournalRec.Validate("Location Code", LocationCode);
        ProdJournalRec.Validate("Bin Code", Bin);
        // ProdJournalRec."User ID" := User;
        if ProdJournalRec2.Get(ProdJournalRec."Journal Template Name", ProdJournalRec."Journal Batch Name", ProdJournalRec."Line No.") then
            ProdJournalRec2.Delete(true);
        ProdJournalRec.Insert(true);

        Message('Production Journal Line for Item %1 added to Order %2.', ItemNo, ProductionOrderNo);
    end;

    // procedure CreateRoutingAndComponents(ProductionOrderNo: Text; RoutingCode: Text; ItemNo: Text)
    // var
    //     RoutingRec: Record "Routing Line"; // Assume this is the routing line table
    //     ProdComponentRec: Record "BOM Component"; // Assume this is the production BOM component table
    //     RoutingLineNo: Integer;
    //     ComponentItemNo: Text;
    //     ComponentQuantity: Decimal;
    // begin
    //     // Create routing lines
    //     RoutingRec.SetRange("No." , RoutingCode);
    //     if RoutingRec.FindSet() then begin
    //         repeat
    //             RoutingLineNo := RoutingRec."Line No.";
    //             // Add routing lines to the production order
    //             Message('Routing Line %1 with Operation %2 added to Production Order %3', RoutingLineNo, RoutingRec."Operation No.", ProductionOrderNo);
    //         until RoutingRec.Next() = 0;
    //     end;

    //     // Create component lines (BOM components)
    //     ProdComponentRec.SetRange("Parent Item No.", ItemNo);
    //     if ProdComponentRec.FindSet() then begin
    //         repeat
    //             ComponentItemNo := ProdComponentRec."Component Item No.";
    //             ComponentQuantity := ProdComponentRec.Quantity;
    //             // Add component to the production order
    //             Message('Component %1 with Quantity %2 added to Production Order %3', ComponentItemNo, ComponentQuantity, ProductionOrderNo);
    //         until ProdComponentRec.Next() = 0;
    //     end;
    // end;
}