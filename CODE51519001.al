codeunit 51519001 WMSIntegrations
{
    Subtype = Normal;

    [ServiceEnabled] // This exposes the codeunit as a web service
    procedure CreateAndRefreshProductionOrderFromAPI(ProdOrderData: Text) Success: Boolean
    var
        ProdOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        ProdJournalLine: Record "Item Journal Line";
        ItemBOM: Record "BOM Component";
        Routing: Record "Routing Line";
        JsonObject: JsonObject;
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        ItemNoToken: JsonToken;
        QuantityToken: JsonToken;
        SourceTypeToken: JsonToken;
        ProductionJournalLinesToken: JsonToken;
        ProductionJournalLineObject: JsonObject;
        RoutingKeyToken: JsonToken;  // New variable for routing key
        ParentItemNo: Code[20];
        JournalQuantity: Decimal;
        ProdOrderNo: Code[20];
        SourceTypeEnum: Enum "Prod. Order Source Type"; // Enum for Source Type
        UoMCode: Code[10]; // Unit of Measure Code inferred from BOM
        JournalLocationCode: Code[10];
        JournalBinCode: Code[20];
        JournalItemNo: Code[20];
        RoutingKey: Text[100];  // Variable to store routing key value
    begin
        // Step 1: Parse the JSON data from the API response
        if not JsonObject.ReadFrom(ProdOrderData) then
            Error('Invalid JSON data provided.');

        // Extract the basic production order details (ItemNo, Quantity, and SourceType)
        ParentItemNo := GetJsonValue(JsonObject, 'ItemNo').AsText();
        JournalQuantity := GetJsonValue(JsonObject, 'Quantity').AsDecimal();
        case GetJsonValue(JsonObject, 'SourceType').AsText() of
            'Item':
                SourceTypeEnum := SourceTypeEnum::Item;
            'Family':
                SourceTypeEnum := SourceTypeEnum::Family;
            'Sales Header':
                SourceTypeEnum := SourceTypeEnum::"Sales Header";
            else
                Error('Invalid Source Type provided.');
        end;

        // Step 2: Parse and handle routing key (if provided)
        if JsonObject.Get('routing', JsonToken) then begin
            JsonObject := JsonToken.AsObject();  // Parse routing object
            if JsonObject.Get('key', RoutingKeyToken) then
                RoutingKeyToken.AsValue().WriteTo(RoutingKey);
        end;

        // Step 3: Create the Production Order
        ProdOrder.Init();
        ProdOrder.Status := ProdOrder.Status::"Released";
        ProdOrder."No." := '';
        ProdOrder."Source No." := ParentItemNo;
        ProdOrder."Source Type" := SourceTypeEnum;
        ProdOrder."Quantity" := JournalQuantity;
        ProdOrder."Starting Date" := WorkDate();
        ProdOrder."Due Date" := WorkDate();
        ProdOrder.Insert(true);

        // Store the production order number for future use
        ProdOrderNo := ProdOrder."No.";

        // Step 4: Post the Production Journal Lines (Consumption) from API
        if JsonObject.Get('ProductionJournalLines', ProductionJournalLinesToken) then begin
            JsonArray := ProductionJournalLinesToken.AsArray();
            foreach JsonToken in JsonArray do begin
                ProductionJournalLineObject := JsonToken.AsObject();

                JournalItemNo := GetJsonValue(ProductionJournalLineObject, 'ItemNo').AsText();
                JournalQuantity := GetJsonValue(ProductionJournalLineObject, 'Quantity').AsDecimal();
                JournalLocationCode := GetJsonValue(ProductionJournalLineObject, 'LocationCode').AsText();
                JournalBinCode := GetJsonValue(ProductionJournalLineObject, 'BIN').AsText();

                // Post each production journal line as consumption
                PostProductionJournalLine(JournalItemNo, JournalQuantity, JournalLocationCode, JournalBinCode, ProdOrderNo, true);
            end;
        end;

        // Step 5: Add one more line for the Output (Finished Product)
        PostProductionJournalLine(ParentItemNo, JournalQuantity, '', '', ProdOrderNo, false); // Output line

        // Step 6: Mark the Production Order as Finished
        SetProductionOrderToFinished(ProdOrderNo);

        // Step 7: Return success
        Success := true; // Indicate that the operation was successful
    end;

    local procedure PostProductionJournalLine(JournalItemNo: Code[20]; JournalQuantity: Decimal; JournalLocationCode: Code[10]; JournalBinCode: Code[20]; ProdOrderNo: Code[20]; IsConsumption: Boolean)
    var
        ProdJournalLine: Record "Item Journal Line";
        ItemJournalPost: Codeunit "Item Jnl.-Post"; // Codeunit for posting
    begin
        ProdJournalLine.Init();
        ProdJournalLine."Journal Template Name" := 'PRODUCTION';
        ProdJournalLine."Journal Batch Name" := 'DEFAULT';
        ProdJournalLine."Document No." := ProdOrderNo;
        ProdJournalLine."Item No." := JournalItemNo;
        ProdJournalLine.Quantity := JournalQuantity;

        if IsConsumption then begin
            ProdJournalLine."Location Code" := JournalLocationCode;
            ProdJournalLine."Bin Code" := JournalBinCode;
            ProdJournalLine."Entry Type" := ProdJournalLine."Entry Type"::Consumption;
        end else begin
            ProdJournalLine."Entry Type" := ProdJournalLine."Entry Type"::Output;
            ProdJournalLine."Location Code" := '';
            ProdJournalLine."Bin Code" := '';
        end;

        ProdJournalLine.Insert();
        ItemJournalPost.Run(ProdJournalLine);
    end;

    local procedure SetProductionOrderToFinished(ProdOrderNo: Code[20])
    var
        ProdOrder: Record "Production Order";
    begin
        if ProdOrder.Get(ProdOrderNo) then begin
            ProdOrder.Status := ProdOrder.Status::Finished;
            ProdOrder.Modify(true);
        end;
    end;

    local procedure GetJsonValue(JsonObject: JsonObject; FieldName: Text): JsonValue
    var
        JsonToken: JsonToken;
    begin
        if not JsonObject.Get(FieldName, JsonToken) then
            Error('%1 is missing from the JSON object.', FieldName);
        exit(JsonToken.AsValue());
    end;
}
