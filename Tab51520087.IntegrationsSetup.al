table 51520087 "Integration Setup"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Code"; Text[100]) // Set Code as the unique identifier
        {
            DataClassification = ToBeClassified;
            Caption = 'Code';
        }

        field(2; "APIBaseUrl"; Text[250])
        {
            DataClassification = ToBeClassified;
            Caption = 'API Base URL';
        }

        field(3; "EndpointUrl"; Text[250])
        {
            DataClassification = ToBeClassified;
            Caption = 'Endpoint URL';
        }

        field(4; "MethodType"; Enum "HTTPMethodType") // Use enum for Method Type
        {
            DataClassification = ToBeClassified;
            Caption = 'Method Type';
        }

        field(5; "ContentType"; Enum "ContentType") // Use enum for Content Type
        {
            DataClassification = ToBeClassified;
            Caption = 'Content Type';
        }

        field(6; "ErrorQueue"; Text[250])
        {
            DataClassification = ToBeClassified;
            Caption = 'Error Queue';
        }

        field(7; "RoutingKey"; Text[250])
        {
            DataClassification = ToBeClassified;
            Caption = 'Routing Key';
        }
    }

    keys
    {
        key(PK; "Code") // Set Code as the primary key
        {
            Clustered = true;
        }
    }
}
