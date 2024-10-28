page 51520084 "Integration Setup List"
{
    PageType = List;
    SourceTable = "Integration Setup";
    ApplicationArea = All;
    Caption = 'API Configurations';
    UsageCategory = Administration;
    CardPageId = "Integration Setup Card";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                }
                field(APIBaseUrl; Rec.APIBaseUrl)
                {
                    ApplicationArea = All;
                }
                field(EndpointUrl; Rec.EndpointUrl)
                {
                    ApplicationArea = All;
                }
                field(MethodType; Rec.MethodType)
                {
                    ApplicationArea = All;
                }
                field(ContentType; Rec.ContentType)
                {
                    ApplicationArea = All;
                }
                field(ErrorQueue; Rec.ErrorQueue)
                {
                    ApplicationArea = All;
                }
                field(RoutingKey; Rec.RoutingKey)
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action("New API Configuration")
            {
                ApplicationArea = All;
                trigger OnAction()
                begin
                    Page.RunModal(Page::"Integration Setup Card");
                end;
            }
        }
    }
}
