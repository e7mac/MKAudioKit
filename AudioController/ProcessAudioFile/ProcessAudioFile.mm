#import "ProcessAudioFile.h"

@interface ProcessAudioFile()

@property (strong, nonatomic) NSURL *sourceURL;
@property (strong, nonatomic) NSURL *destinationURL;
@property (strong, nonatomic) void (^filterBlock)(AudioSampleType& sample);

@end

@implementation ProcessAudioFile

-(void)convertSource:(NSURL *)source destination:(NSURL *)destination  filterBlock:(void (^)(AudioSampleType &sample))filterBlock
{
    self.sourceURL = source;
    self.destinationURL = destination;
    self.filterBlock = filterBlock;
    //TODO: efficiency?
    [self convertAudio];
}

#pragma mark- ExtAudioFile

- (void)convertAudio
{
    OSStatus error = [self doConvertFileSource:(__bridge CFURLRef)self.sourceURL destination:(__bridge CFURLRef)self.destinationURL outputFormat:kAudioFormatMPEG4AAC sampleRate:0];
    if (error) {
        //TODO: get path from URL
        NSString *destinationFilePath;
        // delete output file if it exists since an error was returned during the conversion process
        if ([[NSFileManager defaultManager] fileExistsAtPath:destinationFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:destinationFilePath error:nil];
        }
        printf("DoConvertFile failed! %ld\n", error);
    } else {
        printf("DoConvertFile succeeded!");
    }
}

-(OSStatus)doConvertFileSource:(CFURLRef)sourceURL destination:(CFURLRef)destinationURL outputFormat:(OSType)outputFormat sampleRate:(Float64)outputSampleRate
{
    ExtAudioFileRef sourceFile = 0;
    ExtAudioFileRef destinationFile = 0;
    Boolean         canResumeFromInterruption = true; // we can continue unless told otherwise
    OSStatus        error = noErr;
    
	try {
        CAStreamBasicDescription srcFormat, dstFormat;
        
        // open the source file
        XThrowIfError(ExtAudioFileOpenURL(sourceURL, &sourceFile), "ExtAudioFileOpenURL failed");
        
        // get the source data format
		UInt32 size = sizeof(srcFormat);
		XThrowIfError(ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &size, &srcFormat), "couldn't get source data format");
		
//		printf("\nSource file format: "); srcFormat.Print();
        
        // setup the output file format
        dstFormat.mSampleRate = (outputSampleRate == 0 ? srcFormat.mSampleRate : outputSampleRate); // set sample rate
        if (outputFormat == kAudioFormatLinearPCM) {
            // if PCM was selected as the destination format, create a 16-bit int PCM file format description
            dstFormat.mFormatID = outputFormat;
            dstFormat.mChannelsPerFrame = srcFormat.NumberChannels();
            dstFormat.mBitsPerChannel = 16;
            dstFormat.mBytesPerPacket = dstFormat.mBytesPerFrame = 2 * dstFormat.mChannelsPerFrame;
            dstFormat.mFramesPerPacket = 1;
            dstFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger; // little-endian
        } else {
            // compressed format - need to set at least format, sample rate and channel fields for kAudioFormatProperty_FormatInfo
            dstFormat.mFormatID = outputFormat;
            dstFormat.mChannelsPerFrame =  (outputFormat == kAudioFormatiLBC ? 1 : srcFormat.NumberChannels()); // for iLBC num channels must be 1
            
            // use AudioFormat API to fill out the rest of the description
            size = sizeof(dstFormat);
            XThrowIfError(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &dstFormat), "couldn't create destination data format");
        }
        
        printf("\nDestination file format: "); dstFormat.Print();
        
        // create the destination file
        XThrowIfError(ExtAudioFileCreateWithURL(destinationURL, kAudioFileM4AType, &dstFormat, NULL, kAudioFileFlags_EraseFile, &destinationFile), "ExtAudioFileCreateWithURL failed!");
        
        // set the client format - The format must be linear PCM (kAudioFormatLinearPCM)
        // You must set this in order to encode or decode a non-PCM file data format
        // You may set this on PCM files to specify the data format used in your calls to read/write
        CAStreamBasicDescription clientFormat;
        if (outputFormat == kAudioFormatLinearPCM) {
            clientFormat = dstFormat;
        } else {
            clientFormat.SetCanonical(srcFormat.NumberChannels(), true);
            clientFormat.mSampleRate = srcFormat.mSampleRate;
        }
        
        printf("\nClient data format: "); clientFormat.Print();
        printf("\n");
        
        size = sizeof(clientFormat);
        XThrowIfError(ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat), "couldn't set source client format");
        
        size = sizeof(clientFormat);
        XThrowIfError(ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat), "couldn't set destination client format");
        
        // can the audio converter (which in this case is owned by an ExtAudioFile object) resume conversion after an interruption?
        AudioConverterRef audioConverter;
        
        size = sizeof(audioConverter);
        XThrowIfError(ExtAudioFileGetProperty(destinationFile, kExtAudioFileProperty_AudioConverter, &size, &audioConverter), "Couldn't get Audio Converter!");
        
        // this property may be queried at any time after construction of the audio converter (which in this case is owned by an ExtAudioFile object)
        // after setting the output format -- there's no clear reason to prefer construction time, interruption time, or potential resumption time but we prefer
        // construction time since it means less code to execute during or after interruption time
        UInt32 canResume = 0;
        size = sizeof(canResume);
        error = AudioConverterGetProperty(audioConverter, kAudioConverterPropertyCanResumeFromInterruption, &size, &canResume);
        if (noErr == error) {
            // we recieved a valid return value from the GetProperty call
            // if the property's value is 1, then the codec CAN resume work following an interruption
            // if the property's value is 0, then interruptions destroy the codec's state and we're done
            
            if (0 == canResume) canResumeFromInterruption = false;
            
            printf("Audio Converter %s continue after interruption!\n", (canResumeFromInterruption == 0 ? "CANNOT" : "CAN"));
        } else {
            // if the property is unimplemented (kAudioConverterErr_PropertyNotSupported, or paramErr returned in the case of PCM),
            // then the codec being used is not a hardware codec so we're not concerned about codec state
            // we are always going to be able to resume conversion after an interruption
            
            if (kAudioConverterErr_PropertyNotSupported == error) {
                printf("kAudioConverterPropertyCanResumeFromInterruption property not supported!\n");
            } else {
                printf("AudioConverterGetProperty kAudioConverterPropertyCanResumeFromInterruption result %ld\n", error);
            }
            
            error = noErr;
        }
        
        // set up buffers
        UInt32 bufferByteSize = 32768;
        char srcBuffer[bufferByteSize];
        
        // keep track of the source file offset so we know where to reset the source for
        // reading if interrupted and input was not consumed by the audio converter
        SInt64 sourceFrameOffset = 0;
        
        //***** do the read and write - the conversion is done on and by the write call *****//
        printf("Converting...\n");
        while (1) {
            
            AudioBufferList fillBufList;
            fillBufList.mNumberBuffers = 1;
            fillBufList.mBuffers[0].mNumberChannels = clientFormat.NumberChannels();
            fillBufList.mBuffers[0].mDataByteSize = bufferByteSize;
            fillBufList.mBuffers[0].mData = srcBuffer;
            
            // client format is always linear PCM - so here we determine how many frames of lpcm
            // we can read/write given our buffer size
            UInt32 numFrames;
            if (clientFormat.mBytesPerFrame > 0) // rids bogus analyzer div by zero warning mBytesPerFrame can't be 0 and is protected by an Assert
                numFrames = clientFormat.BytesToFrames(bufferByteSize); // (bufferByteSize / clientFormat.mBytesPerFrame);
            
            XThrowIfError(ExtAudioFileRead(sourceFile, &numFrames, &fillBufList), "ExtAudioFileRead failed!");
            if (!numFrames) {
                // this is our termination condition
                error = noErr;
                break;
            }
            sourceFrameOffset += numFrames;
            
            // this will block if we're interrupted
            //            Boolean wasInterrupted = ThreadStatePausedCheck();
            //
            //            if ((error || wasInterrupted) && (false == canResumeFromInterruption)) {
            //                // this is our interruption termination condition
            //                // an interruption has occured but the audio converter cannot continue
            //                error = kMyAudioConverterErr_CannotResumeFromInterruptionError;
            //                break;
            //            }
            AudioSampleType sample = 0;
            //process start
            for (int bufCount=0; bufCount < fillBufList.mNumberBuffers; bufCount++) {
                AudioBuffer buf = fillBufList.mBuffers[bufCount];
                int currentFrame = 0;
                while ( currentFrame < numFrames ) {
                    // copy sample to buffer, across all channels
                    for (int currentChannel=0; currentChannel<buf.mNumberChannels; currentChannel++) {
                        memcpy(&sample,(char *)buf.mData  + (currentFrame * clientFormat.mBytesPerFrame),sizeof(AudioSampleType));
                        //                        float sampleFloat = (float)sample / 32767; // convert to float for DSP
                        //                        sampleFloat = 0;
                        // get int back
                        //                        NSLog(@"%i", sample);
//                        static int t=0;
//                        sample *= sinf(0.6*t++);// * sampleFloat * 32767;
                        self.filterBlock(sample);
                        //copy sample back
                        memcpy((char *)buf.mData + (currentFrame * clientFormat.mBytesPerFrame),
                               &sample,
                               sizeof(AudioSampleType));
                    }
                    currentFrame++;
                }
            }
            
            //process end
            error = ExtAudioFileWrite(destinationFile, numFrames, &fillBufList);
            // if interrupted in the process of the write call, we must handle the errors appropriately
            if (error) {
                if (kExtAudioFileError_CodecUnavailableInputConsumed == error) {
                    
                    printf("ExtAudioFileWrite kExtAudioFileError_CodecUnavailableInputConsumed error %ld\n", error);
                    
                    /*
                     Returned when ExtAudioFileWrite was interrupted. You must stop calling
                     ExtAudioFileWrite. If the underlying audio converter can resume after an
                     interruption (see kAudioConverterPropertyCanResumeFromInterruption), you must
                     wait for an EndInterruption notification from AudioSession, then activate the session
                     before resuming. In this situation, the buffer you provided to ExtAudioFileWrite was successfully
                     consumed and you may proceed to the next buffer
                     */
                    
                } else if (kExtAudioFileError_CodecUnavailableInputNotConsumed == error) {
                    
                    printf("ExtAudioFileWrite kExtAudioFileError_CodecUnavailableInputNotConsumed error %ld\n", error);
                    
                    /*
                     Returned when ExtAudioFileWrite was interrupted. You must stop calling
                     ExtAudioFileWrite. If the underlying audio converter can resume after an
                     interruption (see kAudioConverterPropertyCanResumeFromInterruption), you must
                     wait for an EndInterruption notification from AudioSession, then activate the session
                     before resuming. In this situation, the buffer you provided to ExtAudioFileWrite was not
                     successfully consumed and you must try to write it again
                     */
                    
                    // seek back to last offset before last read so we can try again after the interruption
                    sourceFrameOffset -= numFrames;
                    XThrowIfError(ExtAudioFileSeek(sourceFile, sourceFrameOffset), "ExtAudioFileSeek failed!");
                    
                } else {
                    XThrowIfError(error, "ExtAudioFileWrite error!");
                }
            } // if
        } // while
	}
    catch (CAXException e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
        error = e.mError;
	}
    
    // close
    if (destinationFile) ExtAudioFileDispose(destinationFile);
    if (sourceFile) ExtAudioFileDispose(sourceFile);
    
    // transition thread state to kStateDone before continuing
    //    ThreadStateSetDone();
    
    return error;
}


@end