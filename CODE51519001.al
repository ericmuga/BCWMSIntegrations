codeunit 51519001 WMSIntegrations
{

    trigger OnRun()
    begin
        // TODO
        /*
            1. Make a get call to fetch production order from API   
            2. Create a production order in Business Central 
        */
        // getProductionOrderFromAPI();
        ProcessProductionOrders(getProductionOrderFromAPI())
    end;

    var
        HttpClient: HttpClient;

    procedure getProductionOrderFromAPI(): Text;
    var
        HttpResponseMessage: HttpResponseMessage;
        ResponseText: Text;
        APIUrl: Text;
        IntegrationSetupRec: Record "Integration Setup";
        EndpointUrl: Text;
        APIBaseUrl: Text;
    begin
        // Retrieve settings from the Integration Setup table
        if not IntegrationSetupRec.Get('fetch-production-orders') then // Use the appropriate "Code" for Production Order API setup
            Error('Integration setup for Production Order API not found.');

        // Construct the API URL using values from the Integration Setup table

        APIBaseUrl := IntegrationSetupRec."APIBaseUrl";
        EndpointUrl := IntegrationSetupRec."EndpointUrl";
        APIUrl := StrSubstNo('%1%2', APIBaseUrl, EndpointUrl);
        // APIUrl := IntegrationSetupRec."APIBaseUrl" + IntegrationSetupRec."EndpointUrl";

        // Check if Method Type is GET
        if IntegrationSetupRec."MethodType" <> IntegrationSetupRec."MethodType"::GET then
            Error('Unsupported HTTP Method Type for fetching production orders.');

        // Make the HTTP GET request
        if HttpClient.Get(APIUrl, HttpResponseMessage) then begin
            if HttpResponseMessage.IsSuccessStatusCode() then begin
                HttpResponseMessage.Content().ReadAs(ResponseText);
                exit(ResponseText); // Return the response text
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
                        if ProductionOrder.Get('ProductionJournalLines', JsonToken) then begin
                            if JsonToken.IsArray() then begin
                                ProductionJournalLinesArray := JsonToken.AsArray();
                                foreach JsonToken in ProductionJournalLinesArray do begin
                                    if JsonToken.IsObject() then begin
                                        ProductionLine := JsonToken.AsObject();
                                        CreateProductionJournalLine(ProductionOrderNo, ProductionLine);
                                    end;
                                end;
                            end;
                        end;
                        //post production journal batch

                        PostProductionJournalBatchWithErrorHandling(ProductionOrderNo)
                        // Create routing and component lines for the production order
                        // CreateRoutingAndComponents(ProductionOrderNo, RoutingCode, ItemNo);
                    end;
                end;
            end;
        end
        else
            Error('Failed to parse JSON response.');
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
        ProductionOrderRec2: Record "Production Order";


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
        ProdOrderRec."Ending Date" := EvaluateDate(DatePart);

        ProductionOrderRec2.Reset();
        ProductionOrderRec2.SetRange("Description 2", ProductionOrderNo);
        //only inset if the production order does not exist
        if not ProductionOrderRec2.FindFirst() then begin
            ProdOrderRec.Insert(true);
            ProdOrderRec."Description 2" := ProductionOrderNo;
            ProdOrderRec.Modify(true);
            CreateOrderLine.Copy(ProdOrderRec, 1, '', false);
        end;

        //Message('Production Order %1 created successfully.', ProdOrderRec."No.");
        exit(true);
    end;

    procedure resolveProductionOrderNo(ProductionOrderNo: Text): Text

    var
        ProdOrderRec: Record "Production Order";
    begin
        ProdOrderRec.SetRange("Description 2", ProductionOrderNo);

        if ProdOrderRec.FindFirst() then
            exit(ProdOrderRec."No.")
        else
            Error('Production Order %1 not found.', ProductionOrderNo);

    end;

    procedure resolveProductionSourceNo(ProductionOrderNo: Text): Text

    var
        ProdOrderRec: Record "Production Order";
    begin
        ProdOrderRec.SetRange("Description 2", ProductionOrderNo);

        if ProdOrderRec.FindFirst() then
            exit(ProdOrderRec."Source No.")
        else
            Error('Production Order %1 not found.', ProductionOrderNo);

    end;



    local procedure resolveOrderLineNo(ProductionOrderNo: Text; ItemNo: Text): Integer
    var
        ProdOrderRec: Record "Prod. Order Line";
    begin
        ProdOrderRec.SetRange("Description 2", ProductionOrderNo);
        // ProdOrderRec.SetRange("Item No.", ItemNo);
        if ProdOrderRec.FindFirst() then
            exit(ProdOrderRec."Line No.")
        else
            exit(0);
    end;


    procedure PostProductionJournalBatchWithErrorHandling(ProductionOrderNo: Text): Boolean
    var
        ItemJournalLine: Record "Item Journal Line";
        Success: Boolean;
        ErrorMessage: Text;
    begin
        // Reset and filter for journal lines related to the production order
        ItemJournalLine.Reset();
        ItemJournalLine.SetRange("Document No.", resolveProductionOrder(ProductionOrderNo));

        if ItemJournalLine.FindSet() then begin
            // Check for sufficient quantity in the consumption location before posting
            repeat
                // if ItemJournalLine."Entry Type" = ItemJournalLine."Entry Type"::Output then
                //     Message(Format(ItemJournalLine.Quantity));

                if ItemJournalLine."Entry Type" = ItemJournalLine."Entry Type"::Consumption then begin
                    if not CheckSufficientQuantity(ItemJournalLine."Item No.", ItemJournalLine."Location Code", ItemJournalLine.Quantity) then begin
                        ErrorMessage := StrSubstNo('Insufficient quantity in location %1 for item %2. Required: %3',
                                                   ItemJournalLine."Location Code", ItemJournalLine."Item No.",
                                                   Format(ItemJournalLine.Quantity));
                        SendErrorToExternalAPI(ErrorMessage, ProductionOrderNo);
                        exit(false);
                    end;
                end;
            until ItemJournalLine.Next() = 0;

            // Try posting the journal batch after validation
            TryPostJournalBatch(ItemJournalLine, Success);
        end else
            // Error('No journal lines found for Production Order %1.', ProductionOrderNo);
            exit(false);
        if Success then
            exit(true)
        // Message('Production Order %1 journal batch posted successfully.', ProductionOrderNo)
        else begin
            ErrorMessage := GetLastErrorText();
            SendErrorToExternalAPI(ErrorMessage, ProductionOrderNo);
            exit(false);
            // Error('Failed to post journal batch for Production Order %1. Error: %2', ProductionOrderNo, ErrorMessage);
        end;
    end;

    // [TryFunction]
    local procedure TryPostJournalBatch(var ItemJournalLine: Record "Item Journal Line"; var Success: Boolean)
    var
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
    begin
        // Attempt to post each item journal line individually
        ItemJnlPostLine.Run(ItemJournalLine);
        Success := true; // Set success to true if posting succeeds
    end;

    procedure CheckSufficientQuantity(ItemNo: Text; LocationCode: Text; RequiredQuantity: Decimal): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        AvailableQuantity: Decimal;
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Location Code", LocationCode);

        // Calculate the total available quantity at the location for the item
        if ItemLedgerEntry.CalcSums("Remaining Quantity") then
            AvailableQuantity := ItemLedgerEntry."Remaining Quantity"
        else
            AvailableQuantity := 0;

        // Return true if the available quantity is sufficient; otherwise, return false
        exit(AvailableQuantity >= RequiredQuantity);
    end;


    procedure SendErrorToExternalAPI(ErrorMessage: Text; OrderNo: Text)
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        JsonObject: JsonObject;
        TextContent: Text;
        ResponseText: Text;
        IntegrationSetupRec: Record "Integration Setup";
        HttpMethod: Enum "HttpMethodType";
        APIBaseUrl: Text;
        ApiEndpoint: Text;
        APIUrl: Text;
        EndpointUrl: Text;

    begin
        // Construct JSON payload
        iF not (IntegrationSetupRec.Get('production-order-error')) then
            Error('Integration setup record not found for production error handling.');
        JsonObject.Add('errorMessage', ErrorMessage);
        JsonObject.Add('orderNo', OrderNo);
        JsonObject.Add('queue', IntegrationSetupRec."ErrorQueue");
        JsonObject.Add('routingKey', IntegrationSetupRec."RoutingKey");
        JsonObject.Add('timestamp', Format(CurrentDateTime, 0, 9));
        JsonObject.WriteTo(TextContent);

        // Prepare HttpContent with JSON payload

        Content.WriteFrom(TextContent);
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', Format(IntegrationSetupRec."ContentType"));

        // Set up the HttpRequestMessage
        APIBaseUrl := IntegrationSetupRec."APIBaseUrl";
        EndpointUrl := IntegrationSetupRec."EndpointUrl";
        APIUrl := StrSubstNo('%1%2', APIBaseUrl, EndpointUrl);
        HttpRequestMessage.Method := Format(IntegrationSetupRec."MethodType"::POST);
        HttpRequestMessage.SetRequestUri(APIUrl);
        HttpRequestMessage.Content := Content;

        // Send the request
        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            if HttpResponseMessage.IsSuccessStatusCode() then begin
                HttpResponseMessage.Content().ReadAs(ResponseText);
                Message('Response from external API: %1', ResponseText);
            end else begin
                Message('Request failed with status code: %1', HttpResponseMessage.HttpStatusCode());
            end;
        end else begin
            Message('Failed to send request to external API.');
        end;
    end;


    procedure InitializeJournalTemplateAndBatch()
    var
        JournalTemplateRec: Record "Item Journal Template";
        JournalBatchRec: Record "Item Journal Batch";
    begin
        if not JournalTemplateRec.Get('OUTPUT') then begin
            JournalTemplateRec."Name" := 'OUTPUT';
            JournalTemplateRec."Type" := JournalTemplateRec."Type"::Output;
            JournalTemplateRec."Description" := 'Output Journal Template';
            JournalTemplateRec.Insert(true);
        end;

        if not JournalTemplateRec.Get('CONSUMP') then begin
            JournalTemplateRec."Name" := 'CONSUMP';
            JournalTemplateRec."Type" := JournalTemplateRec."Type"::Consumption;
            JournalTemplateRec."Description" := 'Consumption Journal Template';
            JournalTemplateRec.Insert(true);
        end;

        if not JournalBatchRec.Get('OUTPUT', 'OUTPUT') then begin
            JournalBatchRec."Name" := 'OUTPUT';
            JournalBatchRec."Journal Template Name" := 'OUTPUT';
            JournalBatchRec."Template Type" := JournalBatchRec."Template Type"::Output;
            JournalBatchRec."Description" := 'Output Journal Batch';
            JournalBatchRec.Insert(true);
        end;

        if not JournalBatchRec.Get('CONSUMP', 'CONSUMP') then begin
            JournalBatchRec."Name" := 'CONSUMP';
            JournalBatchRec."Journal Template Name" := 'CONSUMP';
            JournalBatchRec."Template Type" := JournalBatchRec."Template Type"::Consumption;
            JournalBatchRec."Description" := 'Production Journal Batch';
            JournalBatchRec.Insert(true);
        end;
    end;

    procedure CreateProductionJournalLine(ProductionOrderNo: Text; ProductionLine: JsonObject)
    var
        ProdJournalRec: Record "Item Journal Line";
        ProdJournalRec2: Record "Item Journal Line";
        VariantValue: Variant;
        ItemNo, UOM, LocationCode, Bin, User, DateTimeStr : Text;
        Qty: Decimal;
        LineNo: Integer;
        ProdOrderRec: Record "Production Order";
        Itemrec: Record Item;
        OrderLineNo: Integer;
        EntryType: Text;
        ILE: Record "Item Ledger Entry";
    begin
        InitializeJournalTemplateAndBatch();

        ProdOrderRec.SetRange("Description 2", ProductionOrderNo);

        GetValue(ProductionLine, 'ItemNo', VariantValue);
        ItemNo := VariantValue;

        GetValue(ProductionLine, 'Quantity', VariantValue);
        Qty := VariantValue;

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

        GetValue(ProductionLine, 'type', VariantValue);
        EntryType := VariantValue;

        ProdJournalRec.Init();
        ProdJournalRec."External Document No." := ProductionOrderNo + '-' + Format(LineNo);
        ProdJournalRec.Validate("Item No.", ItemNo);
        ProdJournalRec.Validate("Posting Date", Today);
        ProdJournalRec.Validate("Source Code", 'PRODORDER');
        ProdJournalRec.Validate("Source No.", resolveProductionSourceNo(ProductionOrderNo));
        ProdJournalRec.Validate("Document No.", resolveProductionOrderNo(ProductionOrderNo));

        if Itemrec.Get(ItemNo) then begin
            ProdOrderRec.Validate("Gen. Prod. Posting Group", Itemrec."Gen. Prod. Posting Group");
        end;

        ProdJournalRec."Document Type" := ProdJournalRec."Document Type"::" ";

        if EntryType = 'output' then begin
            ProdJournalRec."Entry Type" := ProdJournalRec."Entry Type"::Output;
            ProdJournalRec.Validate("Journal Template Name", 'OUTPUT');
            ProdJournalRec.Validate("Journal Batch Name", 'OUTPUT');
        end else begin
            ProdJournalRec."Entry Type" := ProdJournalRec."Entry Type"::Consumption;
            ProdJournalRec.Validate("Journal Template Name", 'CONSUMP');
            ProdJournalRec.Validate("Journal Batch Name", 'CONSUMP');
        end;

        ProdJournalRec.Validate("Order Type", ProdJournalRec."Order Type"::Production);

        OrderLineNo := resolveOrderLineNo(ProductionOrderNo, ItemNo);
        if OrderLineNo <> 0 then begin
            ProdJournalRec.Validate("Order No.", resolveProductionOrder(ProductionOrderNo));
            ProdJournalRec.Validate("Order Line No.", OrderLineNo);
        end;

        ProdJournalRec.Validate("Unit of Measure Code", UOM);
        ProdJournalRec.Validate(Quantity, Qty);
        ProdJournalRec.Validate("Line No.", LineNo);
        ProdJournalRec.Validate("Location Code", LocationCode);
        ProdJournalRec.Validate("Bin Code", Bin);

        if ProdJournalRec2.Get(ProdJournalRec."Journal Template Name", ProdJournalRec."Journal Batch Name", ProdJournalRec."Line No.") then begin
            ProdJournalRec2.Delete(true);
        end;

        //only insert if the production journal line does not exist
        ILE.SetRange("Item No.", ItemNo);
        ILE.SetRange("Location Code", LocationCode);
        ILE.SetRange("External Document No.", ProductionOrderNo + '-' + Format(LineNo));
        ILE.SetRange("Source No.", resolveProductionOrderNo(ProductionOrderNo));
        ILE.SetRange("Document No.", resolveProductionOrderNo(ProductionOrderNo));
        if not ILE.FindFirst() then begin
            ProdJournalRec.Insert(true);
        end;


        if (EntryType = 'output') then begin
            ProdJournalRec.Validate(Quantity, Qty);
            ProdJournalRec.Modify(true);
        end;

        // Message('Production Journal Line for Item %1 with qty: %3 added to Order %2.', ItemNo, resolveProductionOrder(ProductionOrderNo), Format(Qty));
    end;
}



