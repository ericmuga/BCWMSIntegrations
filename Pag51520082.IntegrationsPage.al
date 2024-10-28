page 51520082 IntegrationsPage
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Integrations';

    actions
    {
        area(Processing)
        {
            action("Fetch Production Orders")
            {
                ApplicationArea = All;
                trigger OnAction()
                var
                    WMSIntegrations: Codeunit 51519001;
                begin
                    WMSIntegrations.ProcessProductionOrders(WMSIntegrations.getProductionOrderFromAPI());
                end;
            }

            action("View API Integrations")
            {
                ApplicationArea = All;
                trigger OnAction()
                begin
                    Page.Run(Page::"Integration Setup List");
                end;
            }

            action("Pending Production Orders")
            {
                ApplicationArea = All;
                trigger OnAction()
                var
                    ProductionOrderRec: Record "Production Order";
                begin
                    // Set filters for Released status and non-empty Description 2 field
                    ProductionOrderRec.SetRange(Status, ProductionOrderRec.Status::Released);
                    ProductionOrderRec.SetFilter("Description 2", '<>%1', '');

                    // Run the Production Order List page with the filtered records
                    PAGE.Run(PAGE::"Production Order List", ProductionOrderRec);
                end;
            }

            action("Processed Production Orders")
            {
                ApplicationArea = All;
                trigger OnAction()
                var
                    ItemLedgerEntry: Record "Item Ledger Entry";
                    ItemlegerEntryList: Page "Item Ledger Entries";
                begin

                    ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Order Type", ItemLedgerEntry."Order Type"::Production);
                    ItemLedgerEntry.SetFilter("Posting Date", '>=%1', Today());
                    ItemLedgerEntry.SetFilter("External Document No.", '<>%1', '');
                    ItemLedgerEntry.SetFilter("Entry Type", 'Consumption|Output');
                    PAGE.Run(PAGE::"Item Ledger Entries", ItemLedgerEntry);

                end;
            }




        }
    }

    // Triggers section for the page
    trigger OnOpenPage()
    begin
        EnsureAPIsExist();
    end;

    // Local procedure to ensure specific APIs are present in the setup
    local procedure EnsureAPIsExist()
    var
        IntegrationSetupRec: Record "Integration Setup";
    begin
        // Check and insert the 'fetch-production-order' API if it doesn't exist
        if not IntegrationSetupRec.Get('fetch-production-orders') then begin
            IntegrationSetupRec.Init();
            IntegrationSetupRec."Code" := 'fetch-production-orders';
            IntegrationSetupRec."APIBaseUrl" := 'http://100.100.2.39:3000/';
            IntegrationSetupRec."EndpointUrl" := 'fetch-production-orders';
            IntegrationSetupRec."MethodType" := IntegrationSetupRec.MethodType::GET;
            IntegrationSetupRec."ContentType" := IntegrationSetupRec.ContentType::JSON;
            IntegrationSetupRec.Insert();
        end;

        // Check and insert the 'production-order-error' API if it doesn't exist
        if not IntegrationSetupRec.Get('production-order-error') then begin
            IntegrationSetupRec.Init();
            IntegrationSetupRec."Code" := 'production-order-error';
            IntegrationSetupRec."APIBaseUrl" := 'http://100.100.2.39:3000/';
            IntegrationSetupRec."EndpointUrl" := 'production-order-error';
            IntegrationSetupRec."MethodType" := IntegrationSetupRec.MethodType::POST;
            IntegrationSetupRec."ContentType" := IntegrationSetupRec.ContentType::JSON;
            IntegrationSetupRec.Insert();
        end;
    end;
}
