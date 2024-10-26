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
        }
    }


}

