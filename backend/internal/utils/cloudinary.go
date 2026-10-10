package utils

import (
	"context"
	"fmt"
	"mime/multipart"

	"github.com/cloudinary/cloudinary-go/v2"
	"github.com/cloudinary/cloudinary-go/v2/api/uploader"
)

// CloudinaryUploader handles image uploads to Cloudinary
type CloudinaryUploader struct {
	cld *cloudinary.Cloudinary
}

// NewCloudinaryUploader creates a new CloudinaryUploader instance
func NewCloudinaryUploader(cloudName, apiKey, apiSecret string) (*CloudinaryUploader, error) {
	if cloudName == "" || apiKey == "" || apiSecret == "" {
		return nil, fmt.Errorf("cloudinary credentials not configured")
	}

	cld, err := cloudinary.NewFromParams(cloudName, apiKey, apiSecret)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize cloudinary: %w", err)
	}

	return &CloudinaryUploader{cld: cld}, nil
}

// UploadFile uploads a multipart file to Cloudinary under the mediq/prescriptions folder
// Returns the secure HTTPS URL of the uploaded image
func (cu *CloudinaryUploader) UploadFile(file multipart.File, publicID string) (string, error) {
	ctx := context.Background()

	uploadResult, err := cu.cld.Upload.Upload(ctx, file, uploader.UploadParams{
		PublicID: publicID,
		Folder:   "mediq/prescriptions",
		// Auto-optimize image quality and format
		Transformation: "q_auto,f_auto",
	})
	if err != nil {
		return "", fmt.Errorf("cloudinary upload failed: %w", err)
	}

	return uploadResult.SecureURL, nil
}

// DeleteFile deletes an image from Cloudinary by its public ID
func (cu *CloudinaryUploader) DeleteFile(publicID string) error {
	ctx := context.Background()
	_, err := cu.cld.Upload.Destroy(ctx, uploader.DestroyParams{PublicID: publicID})
	return err
}
